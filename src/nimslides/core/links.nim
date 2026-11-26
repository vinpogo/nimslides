## Link parsing shared by the links and images features: link text, inline
## destinations and titles, and link reference definitions.
##
## Core collects reference definitions itself, with a paragraph-start hook
## registered here, and stores them in document state. The procs below only
## read `p.src` and never move `p.pos`: they return where the parsed part
## stops, and the calling rule sets `p.pos` when it matches.
##
## Not covered (simplifications): HTML entities in destinations and titles,
## full Unicode case folding of labels (labels are lowercased), and the
## precedence of autolinks and raw HTML over brackets in link text.

import std/[strutils, tables, unicode]
import ./[ast, inlines, registry]

const maxLabelLen* = 999 ## CommonMark's limit for link labels

type
  LinkText* = object ## The bracketed part of a link or image, `[text]`.
    found*: bool
    text*: string ## the raw text between the brackets, for `p.parseInlines`
    start*: int ## index of `[`
    stop*: int ## index after `]`

  LinkTarget* = object
    ## Where a link points, from `(url "title")` or a reference definition.
    found*: bool
    url*: string ## backslash escapes resolved
    title*: string ## "" if there is none; backslash escapes resolved
    stop*: int ## index after the link's tail: `)`, `[label]`, `[]` or `]`

  LinkReference* = tuple[url, title: string]

  LinkReferences* = ref object of RootObj
    ## The document's reference definitions, by normalised label.
    table*: Table[string, LinkReference]

const referencesKey = "core.links" ## the `doc.state` key of `LinkReferences`

proc resolveEscapes*(s: string): string =
  ## `s` with backslash escapes of ASCII punctuation resolved.
  var i = 0
  while i < s.len:
    if s[i] == '\\' and i + 1 < s.len and s[i + 1] in asciiPunctuation:
      result.add s[i + 1]
      i += 2
    else:
      result.add s[i]
      inc i

proc normalizeLabel*(label: string): string =
  ## `label` lowercased, with runs of whitespace collapsed to one space and
  ## none at either end: how reference labels are compared.
  for word in strutils.splitWhitespace(label):
    if result.len > 0:
      result.add ' '
    result.add word
  result = unicode.toLower(result)

proc skipWhitespace(s: string, i: int): int =
  ## Index after spaces and tabs from `i`, with at most one line ending
  ## among them.
  result = i
  var newline = false
  while result < s.len:
    case s[result]
    of ' ', '\t':
      inc result
    of '\n':
      if newline:
        break
      newline = true
      inc result
    else:
      break

proc lineEnd(s: string, i: int): int =
  ## The index of the line ending (or the end of `s`) if only spaces and
  ## tabs follow `i` on its line, else -1.
  result = i
  while result < s.len and s[result] in {' ', '\t'}:
    inc result
  if result < s.len and s[result] != '\n':
    result = -1

proc skipCodeSpan(s: string, i: int): int =
  ## `s[i]` is a backtick: the index after the code span starting here, or
  ## after the backtick run if no run of the same length closes it.
  var n = 0
  while i + n < s.len and s[i + n] == '`':
    inc n
  var j = i + n
  while j < s.len:
    if s[j] == '`':
      var m = 0
      while j + m < s.len and s[j + m] == '`':
        inc m
      if m == n:
        return j + m
      j += m
    else:
      inc j
  i + n

proc escapedAt(s: string, i: int): bool =
  ## Whether `s[i]` is a backslash escaping ASCII punctuation.
  s[i] == '\\' and i + 1 < s.len and s[i + 1] in asciiPunctuation

proc linkText*(src: string, start: int): LinkText =
  ## The link text starting at `src[start] == '['`, up to its matching `]`.
  ## Brackets nest; escaped brackets and brackets inside code spans don't
  ## count.
  if start notin 0 ..< src.len or src[start] != '[':
    return
  var depth = 0
  var i = start + 1
  while i < src.len:
    if src.escapedAt(i):
      i += 2
      continue
    case src[i]
    of '`':
      i = src.skipCodeSpan(i)
      continue
    of '[':
      inc depth
    of ']':
      if depth == 0:
        return
          LinkText(found: true, text: src[start + 1 ..< i], start: start, stop: i + 1)
      dec depth
    else:
      discard
    inc i

proc linkText*(p: InlineParser): LinkText =
  ## The link text at the cursor; see `linkText(src, start)`. For an image,
  ## use `linkText(p.src, p.pos + 1)` to skip the `!`.
  linkText(p.src, p.pos)

proc linkLabel*(src: string, start: int): LinkText =
  ## A reference label `[label]` at `src[start]`: at most `maxLabelLen`
  ## characters, not blank, no unescaped brackets inside.
  if start notin 0 ..< src.len or src[start] != '[':
    return
  var i = start + 1
  while i < src.len and i - start - 1 <= maxLabelLen:
    if src.escapedAt(i):
      i += 2
      continue
    case src[i]
    of '[':
      return
    of ']':
      let text = src[start + 1 ..< i]
      if text.len > maxLabelLen or text.isEmptyOrWhitespace:
        return
      return LinkText(found: true, text: text, start: start, stop: i + 1)
    else:
      inc i

proc parseDestination(
    s: string, i: int, allowEmpty: bool
): tuple[ok: bool, url: string, stop: int] =
  ## `<dest>` (no line endings, no unescaped `<`), or a bare destination
  ## without spaces or control characters and with balanced parentheses.
  if i < s.len and s[i] == '<':
    var j = i + 1
    while j < s.len:
      if s.escapedAt(j):
        j += 2
        continue
      case s[j]
      of '\n', '<':
        return
      of '>':
        return (true, resolveEscapes(s[i + 1 ..< j]), j + 1)
      else:
        inc j
    return
  var depth = 0
  var j = i
  while j < s.len:
    if s.escapedAt(j):
      j += 2
      continue
    let c = s[j]
    if c <= ' ' or c == '\x7f':
      break
    if c == '(':
      inc depth
    elif c == ')':
      if depth == 0:
        break
      dec depth
    inc j
  if depth != 0 or (j == i and not allowEmpty):
    return
  (true, resolveEscapes(s[i ..< j]), j)

proc parseTitle(s: string, i: int): tuple[ok: bool, title: string, stop: int] =
  ## `"title"`, `'title'` or `(title)`; the delimiter inside only escaped,
  ## and for `(…)` neither parenthesis.
  if i >= s.len:
    return
  let close =
    case s[i]
    of '"':
      '"'
    of '\'':
      '\''
    of '(':
      ')'
    else:
      return
  var j = i + 1
  while j < s.len:
    if s.escapedAt(j):
      j += 2
      continue
    if s[j] == close:
      return (true, resolveEscapes(s[i + 1 ..< j]), j + 1)
    if close == ')' and s[j] == '(':
      return
    inc j

proc inlineTarget*(src: string, start: int): LinkTarget =
  ## An inline link tail `(dest "title")` at `src[start] == '('`. Both parts
  ## are optional; whitespace with up to one line ending may surround them,
  ## and the title must be separated from the destination by it.
  if start notin 0 ..< src.len or src[start] != '(':
    return
  var i = src.skipWhitespace(start + 1)
  let dest = src.parseDestination(i, allowEmpty = true)
  if not dest.ok:
    return
  i = dest.stop
  var title = ""
  let j = src.skipWhitespace(i)
  if j > i:
    let t = src.parseTitle(j)
    if t.ok:
      title = t.title
      i = src.skipWhitespace(t.stop)
    else:
      i = j
  if i < src.len and src[i] == ')':
    result = LinkTarget(found: true, url: dest.url, title: title, stop: i + 1)

proc references*(doc: DocCtx): LinkReferences =
  ## The document's link reference definitions.
  doc.state(referencesKey, LinkReferences)

proc defineReference*(doc: DocCtx, label, url: string, title = ""): bool =
  ## Stores a reference definition unless its label is blank or already
  ## defined (the first definition wins). Returns whether it was stored.
  let key = normalizeLabel(label)
  if key.len == 0 or key in doc.references.table:
    return false
  doc.references.table[key] = (url, title)
  true

proc lookupReference*(doc: DocCtx, label: string): LinkTarget =
  ## The definition for `label` (compared normalised); `stop` is left 0.
  let key = normalizeLabel(label)
  if key.len > 0 and key in doc.references.table:
    let (url, title) = doc.references.table[key]
    result = LinkTarget(found: true, url: url, title: title)

proc referenceTarget*(p: InlineParser, text: LinkText): LinkTarget =
  ## A reference link after `text`: full `[text][label]`, collapsed
  ## `[text][]` or shortcut `[text]`. A shortcut is not tried when a label or
  ## `[]` follows, even an undefined one (as in CommonMark).
  let s = p.src
  let i = text.stop
  var stop: int
  if i + 1 < s.len and s[i] == '[' and s[i + 1] == ']':
    result = p.doc.lookupReference(text.text)
    stop = i + 2
  elif (let label = s.linkLabel(i); label.found):
    result = p.doc.lookupReference(label.text)
    stop = label.stop
  else:
    result = p.doc.lookupReference(text.text)
    stop = i
  if text.text.len > maxLabelLen:
    result = LinkTarget()
  if result.found:
    result.stop = stop

proc parseLinkTail*(p: InlineParser, text: LinkText): LinkTarget =
  ## What follows link text `text` (from `linkText`): an inline
  ## `(dest "title")`, else a reference. Not found if `text` was not found.
  ## On a match the rule sets `p.pos = result.stop`.
  if not text.found:
    return
  if text.stop < p.src.len and p.src[text.stop] == '(':
    result = inlineTarget(p.src, text.stop)
    if result.found:
      return
  result = p.referenceTarget(text)

proc parseDefinition*(
    src: string
): tuple[ok: bool, label, url, title: string, stop: int] =
  ## A reference definition `[label]: dest "title"` at the start of `src`
  ## (lines joined by "\n"). `stop` is the index of the line ending (or the
  ## end) after it. A title on the next line followed by other text is not
  ## part of the definition; on the same line it makes the definition
  ## invalid.
  let label = src.linkLabel(0)
  if not label.found or label.stop >= src.len or src[label.stop] != ':':
    return
  var i = src.skipWhitespace(label.stop + 1)
  let dest = src.parseDestination(i, allowEmpty = false)
  if not dest.ok:
    return
  i = dest.stop
  let j = src.skipWhitespace(i)
  if j > i:
    let t = src.parseTitle(j)
    if t.ok and (let e = src.lineEnd(t.stop); e >= 0):
      return (true, label.text, dest.url, t.title, e)
  if (let e = src.lineEnd(i); e >= 0):
    return (true, label.text, dest.url, "", e)

proc consumeDefinition(lines: seq[string], doc: DocCtx): int =
  ## Paragraph-start hook: takes one definition from the paragraph's start.
  if not lines[0].startsWith('['):
    return 0
  let src = lines.join("\n")
  let d = parseDefinition(src)
  if not d.ok:
    return 0
  discard doc.defineReference(d.label, d.url, d.title)
  src[0 ..< d.stop].count('\n') + 1

registerParagraphStart ParagraphStart(
  name: "link_reference_definitions", priority: 10, consume: consumeDefinition
)
