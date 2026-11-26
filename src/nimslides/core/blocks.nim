## The block parser driver: a line cursor for block rules, the paragraph
## fallback with its hooks, and recursion for containers.

import std/[strutils, unicode]
import ./[ast, registry]

proc expandTabs*(line: string, tabStop = 4): string =
  ## `line` with tabs replaced by spaces up to the next multiple of
  ## `tabStop` columns (CommonMark uses 4).
  if '\t' notin line:
    return line
  var col = 0
  for r in line.runes:
    if r == Rune('\t'):
      let n = tabStop - col mod tabStop
      result.add ' '.repeat(n)
      col += n
    else:
      result.add $r
      inc col

proc newBlockParser*(lines: seq[string], doc: DocCtx): BlockParser =
  ## A parser over `lines`; tabs are expanded here.
  result = BlockParser(doc: doc)
  for line in lines:
    result.lines.add line.expandTabs

proc eof*(p: BlockParser): bool =
  p.pos >= p.lines.len

proc peek*(p: BlockParser, offset = 0): string =
  ## The line `offset` lines after the current one, or "" past the end.
  let i = p.pos + offset
  if i in 0 ..< p.lines.len:
    p.lines[i]
  else:
    ""

proc line*(p: BlockParser): string =
  ## The current line, or "" at the end.
  p.peek(0)

proc advance*(p: BlockParser, n = 1) =
  p.pos = min(p.pos + n, p.lines.len)

proc isBlank*(line: string): bool =
  line.allCharsInSet({' ', '\t'})

proc indentOf*(line: string): int =
  ## Number of leading spaces.
  while result < line.len and line[result] == ' ':
    inc result

proc takeWhile*(p: BlockParser, pred: proc(line: string): bool): seq[string] =
  ## Collects lines from the current one while `pred` holds.
  while not p.eof and pred(p.line):
    result.add p.line
    p.advance

proc tryRules(p: BlockParser, interruptingOnly: bool): BlockNode =
  for rule in registered.blockRules:
    if interruptingOnly and not rule.interruptsParagraph:
      continue
    let start = p.pos
    let node = rule.parse(p)
    if node != nil:
      doAssert p.pos > start, rule.name & " matched without advancing"
      return node
    p.pos = start

proc interruptsParagraph*(p: BlockParser): bool =
  ## Whether a rule with `interruptsParagraph` starts a block on the current
  ## line. Rules see `p.interrupting == true` and must not change `p.doc`.
  let (start, saved) = (p.pos, p.interrupting)
  p.interrupting = true
  result = p.tryRules(interruptingOnly = true) != nil
  p.pos = start
  p.interrupting = saved

proc claimedBefore*(p: BlockParser, priority: int): bool =
  ## Whether a block rule that runs before `priority` starts on the current
  ## line, e.g. a thematic break for `* * *` before lists. Rules are asked as
  ## for an interruption (`p.interrupting`), so they don't change `p.doc`.
  ## The cursor is left where it was.
  let (start, saved) = (p.pos, p.interrupting)
  p.interrupting = true
  defer:
    p.pos = start
    p.interrupting = saved
  for rule in registered.blockRules:
    if rule.priority >= priority:
      break
    if rule.parse(p) != nil:
      return true
    p.pos = start

proc parseParagraph(p: BlockParser): BlockNode =
  ## Core's fallback: lines up to a blank line, a closer or an interruption.
  var lines = @[p.line.strip(trailing = false)]
  p.advance
  var build: ParagraphBuild
  var closedAt = -1
  while not p.eof and not p.line.isBlank:
    let at = p.pos
    for closer in registered.closers:
      build = closer.close(p)
      if build != nil:
        closedAt = at
        break
      p.pos = at
    if build != nil or p.interruptsParagraph:
      break
    lines.add p.line.strip(trailing = false)
    p.advance

  var taken = true
  while taken and lines.len > 0:
    taken = false
    for hook in registered.starts:
      let n = hook.consume(lines, p.doc)
      if n > 0:
        lines = lines[min(n, lines.len) .. ^1]
        taken = true
        break

  if lines.len == 0:
    if build != nil:
      p.pos = closedAt # the closing line is parsed afresh
    return nil
  if build != nil:
    return build(lines)
  Paragraph(raw: lines.join("\n").strip(leading = false))

proc parseBlocks*(p: BlockParser): seq[BlockNode] =
  ## Parses the lines from the cursor to the end.
  while not p.eof:
    if p.line.isBlank:
      p.advance
      continue
    let node = p.tryRules(interruptingOnly = false)
    if node != nil:
      result.add node
    else:
      let para = p.parseParagraph()
      if para != nil:
        result.add para

proc parseBlocks*(p: BlockParser, lines: seq[string]): seq[BlockNode] =
  ## For containers: parses `lines` (e.g. a quote's content without the
  ## `>` markers) as blocks of their own, sharing the document state.
  let inner = newBlockParser(lines, p.doc)
  inner.nested = true
  inner.parseBlocks()

proc scratchBlocks*(lines: seq[string]): seq[BlockNode] =
  ## For containers: `lines` parsed with throwaway document state, to look at
  ## their structure (e.g. `endsInParagraph`) without recording anything,
  ## such as link reference definitions, in the real document.
  newBlockParser(lines, newDocCtx()).parseBlocks()

proc isLazy*(p: BlockParser, inner: seq[string]): bool =
  ## For containers: whether the current line, which lacks the container's
  ## marker or indent, is a lazy continuation of a paragraph left open at
  ## the end of `inner`, the container's content lines so far. Add it to
  ## `inner` as `lazyLine(p.line)`.
  inner.len > 0 and not inner[^1].isBlank and not p.line.isBlank and
    not p.interruptsParagraph and scratchBlocks(inner).endsInParagraph

proc lazyLine*(line: string): string =
  ## A lazy continuation line made safe to add to a container's content:
  ## indented 4 spaces, so it can only continue the open paragraph, never
  ## start a block or be a setext underline. Paragraphs drop the indent.
  "    " & line.strip(trailing = false)

proc parseDocument*(src: string, doc: DocCtx): seq[BlockNode] =
  newBlockParser(src.splitLines, doc).parseBlocks()
