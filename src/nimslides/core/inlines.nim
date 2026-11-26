## The inline parser driver: plain text, backslash escapes, soft line
## breaks, dispatch to inline rules, and CommonMark's delimiter-run
## matching for the registered delimiter rules.
##
## Inline text is parsed during layout, after the whole document's blocks
## are parsed, so document state such as link reference definitions is
## complete by then.

import std/[sequtils, unicode]
import pkg/unicodedb/properties
import ./[ast, registry]

const asciiPunctuation* = {'!' .. '/', ':' .. '@', '[' .. '`', '{' .. '~'}
  ## what a backslash escapes

type Delim = object
  idx: int ## index of the run's `Text` node in the item list
  rule: int ## index into `registered.delimiters`
  count, orig: int ## delimiters left in the run, and its original length
  canOpen, canClose: bool

proc peek*(p: InlineParser, offset = 0): char =
  ## The character `offset` places after the cursor, or '\0' past either end.
  let i = p.pos + offset
  if i in 0 ..< p.src.len:
    p.src[i]
  else:
    '\0'

proc isUnicodeSpace(r: Rune): bool =
  int(r) in [0x09, 0x0A, 0x0C, 0x0D, 0x20] or r.unicodeCategory == ctgZs

proc isUnicodePunct(r: Rune): bool =
  if int(r) < 0x80:
    char(int(r)) in asciiPunctuation
  else:
    r.unicodeCategory in ctgP + ctgS

proc runeBefore(s: string, i: int): Rune =
  ## The code point ending before byte `i`; a space at the start.
  if i <= 0:
    return Rune(0x20)
  var j = i - 1
  while j > 0 and (s[j].ord and 0xC0) == 0x80:
    dec j
  s.runeAt(j)

proc runeFrom(s: string, i: int): Rune =
  ## The code point at byte `i`; a space at the end.
  if i >= s.len:
    Rune(0x20)
  else:
    s.runeAt(i)

proc processEmphasis(items: var seq[InlineNode], delims: var seq[Delim]) =
  ## CommonMark's "process emphasis" over the whole item list.
  var ci = 0
  while ci < delims.len:
    let closer = delims[ci]
    if not closer.canClose:
      inc ci
      continue
    let rule = registered.delimiters[closer.rule]
    var found = -1
    for oi in countdown(ci - 1, 0):
      let o = delims[oi]
      if o.rule != closer.rule or not o.canOpen:
        continue
      if rule.sameLength and o.count != closer.count:
        continue
      if rule.ruleOf3 and (o.canClose or closer.canOpen) and
          (o.orig + closer.orig) mod 3 == 0 and
          not (o.orig mod 3 == 0 and closer.orig mod 3 == 0):
        continue
      found = oi
      break
    if found < 0:
      if closer.canOpen:
        inc ci
      else:
        delims.delete(ci)
      continue

    let opener = delims[found]
    let n =
      if rule.sameLength:
        closer.count
      elif opener.count >= 2 and closer.count >= 2:
        2
      else:
        1
    let openText = Text(items[opener.idx])
    openText.text.setLen(openText.text.len - n)
    let closeText = Text(items[closer.idx])
    closeText.text = closeText.text[n .. ^1]
    var children: seq[InlineNode]
    for item in items[opener.idx + 1 ..< closer.idx]:
      if not (item of Text and Text(item).text.len == 0):
        children.add item # skips runs that are used up
    let node = rule.build(n, children)
    let removed = closer.idx - opener.idx - 1
    items[opener.idx + 1 ..< closer.idx] = [node]
    if ci - 1 >= found + 1:
      delims.delete(found + 1 .. ci - 1)
    ci = found + 1
    for k in ci ..< delims.len:
      delims[k].idx -= removed - 1
    delims[found].count -= n
    delims[ci].count -= n
    if delims[ci].count == 0:
      delims.delete(ci)
    if delims[found].count == 0:
      delims.delete(found)
      dec ci

proc parseInlines*(src: string, doc: DocCtx): seq[InlineNode] =
  ## The inline nodes of `src`, e.g. a paragraph's raw text.
  let p = InlineParser(src: src, doc: doc)
  var stops = {'\\', '\n'}
  for rule in registered.inlineRules:
    stops.incl rule.triggers
  for rule in registered.delimiters:
    stops.incl rule.ch

  var items: seq[InlineNode]
  var delims: seq[Delim]
  var text = ""
  template flush() =
    if text.len > 0:
      items.add Text(text: text)
      text = ""

  while p.pos < src.len:
    let c = src[p.pos]
    if c notin stops:
      text.add c
      inc p.pos
      continue

    var matched = false
    for rule in registered.inlineRules:
      if c in rule.triggers:
        let start = p.pos
        let node = rule.parse(p)
        if node != nil:
          doAssert p.pos > start, rule.name & " matched without advancing"
          flush()
          items.add node
          matched = true
          break
        p.pos = start
    if matched:
      continue

    if c == '\\':
      if p.peek(1) in asciiPunctuation:
        text.add p.peek(1)
        p.pos += 2
      else:
        text.add c
        inc p.pos
    elif c == '\n': # soft line break: one space
      while text.len > 0 and text[^1] == ' ':
        text.setLen(text.len - 1)
      text.add ' '
      inc p.pos
      while p.peek in {' ', '\t'}:
        inc p.pos
    elif (let d = delimiterFor(c); d >= 0):
      let rule = registered.delimiters[d]
      let start = p.pos
      while p.peek == c:
        inc p.pos
      let run = src[start ..< p.pos]
      if rule.maxRun > 0 and run.len > rule.maxRun:
        text.add run
        continue
      let before = src.runeBefore(start)
      let after = src.runeFrom(p.pos)
      let left =
        not after.isUnicodeSpace and
        (not after.isUnicodePunct or before.isUnicodeSpace or before.isUnicodePunct)
      let right =
        not before.isUnicodeSpace and
        (not before.isUnicodePunct or after.isUnicodeSpace or after.isUnicodePunct)
      var delim = Delim(rule: d, count: run.len, orig: run.len)
      if rule.intraword:
        delim.canOpen = left
        delim.canClose = right
      else:
        delim.canOpen = left and (not right or before.isUnicodePunct)
        delim.canClose = right and (not left or after.isUnicodePunct)
      flush()
      delim.idx = items.len
      items.add Text(text: run)
      if delim.canOpen or delim.canClose:
        delims.add delim
    else:
      text.add c
      inc p.pos
  flush()

  processEmphasis(items, delims)

  # Merge neighbouring text, now that delimiter runs are plain text again.
  for item in items:
    if item of Text and Text(item).text.len == 0:
      continue
    if item of Text and result.len > 0 and result[^1] of Text:
      Text(result[^1]).text.add Text(item).text
    else:
      result.add item

proc parseInlines*(p: InlineParser, src: string): seq[InlineNode] =
  ## Parses nested inline content, e.g. a link's label, with the same
  ## document state.
  parseInlines(src, p.doc)
