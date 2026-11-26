## HTML blocks (CommonMark types 1-7). Comments render nothing, so they can
## hold speaker notes; other HTML blocks show their raw text, hard-wrapped.

import std/strutils
import ../core

type HtmlBlock* = ref object of BlockNode
  kind*: int ## the CommonMark start condition, 1-7
  lines*: seq[string] ## the raw lines, indentation kept

const
  rawTags = ["pre", "script", "style", "textarea"] ## type 1
  blockTags = [ ## type 6
    "address", "article", "aside", "base", "basefont", "blockquote", "body", "caption",
    "center", "col", "colgroup", "dd", "details", "dialog", "dir", "div", "dl", "dt",
    "fieldset", "figcaption", "figure", "footer", "form", "frame", "frameset", "h1",
    "h2", "h3", "h4", "h5", "h6", "head", "header", "hr", "html", "iframe", "legend",
    "li", "link", "main", "menu", "menuitem", "nav", "noframes", "ol", "optgroup",
    "option", "p", "param", "search", "section", "summary", "table", "tbody", "td",
    "tfoot", "th", "thead", "title", "tr", "track", "ul",
  ]
  ends = ["", "", "-->", "?>", ">", "]]>"] ## end markers of types 2-5, by type

proc tagName(s: string, i: int): int =
  ## The end of the tag name starting at `i`, or `i` if there is none.
  result = i
  if result < s.len and s[result] in Letters:
    inc result
    while result < s.len and s[result] in Letters + Digits + {'-'}:
      inc result

proc skipSpace(s: string, i: int): int =
  result = i
  while result < s.len and s[result] in {' ', '\t', '\n'}:
    inc result

proc attribute(s: string, i: int): int =
  ## The end of an attribute (with whitespace before it) at `i`, or -1.
  var j = s.skipSpace(i)
  if j == i or j >= s.len or s[j] notin Letters + {'_', ':'}:
    return -1
  inc j
  while j < s.len and s[j] in Letters + Digits + {'_', '.', ':', '-'}:
    inc j
  let k = s.skipSpace(j)
  if k >= s.len or s[k] != '=':
    return j # no value
  var v = s.skipSpace(k + 1)
  if v >= s.len:
    return -1
  if s[v] in {'"', '\''}:
    let close = s.find(s[v], v + 1)
    return (if close < 0: -1 else: close + 1)
  let start = v
  while v < s.len and s[v] notin {' ', '\t', '\n', '"', '\'', '=', '<', '>', '`'}:
    inc v
  (if v > start: v else: -1)

proc completeTag(s: string): int =
  ## The end of a complete open or closing tag at the start of `s`, or -1.
  if s.len < 3 or s[0] != '<':
    return -1
  if s[1] == '/':
    let name = s.tagName(2)
    if name == 2:
      return -1
    let j = s.skipSpace(name)
    return (if j < s.len and s[j] == '>': j + 1 else: -1)
  var j = s.tagName(1)
  if j == 1:
    return -1
  while true:
    let next = s.attribute(j)
    if next < 0:
      break
    j = next
  j = s.skipSpace(j)
  if j < s.len and s[j] == '/':
    inc j
  (if j < s.len and s[j] == '>': j + 1 else: -1)

proc startKind(line: string): int =
  ## The HTML block type that `line` starts, or 0.
  let indent = indentOf(line)
  if indent > 3 or indent >= line.len or line[indent] != '<':
    return 0
  let s = line[indent .. ^1]
  let lower = s.toLowerAscii

  proc endsName(at: int): bool =
    at >= s.len or s[at] in {' ', '\t', '>'}

  for tag in rawTags:
    if lower.continuesWith(tag, 1) and endsName(1 + tag.len):
      return 1
  if s.startsWith("<!--"):
    return 2
  if s.startsWith("<?"):
    return 3
  if s.len > 2 and s[1] == '!' and s[2] in Letters:
    return 4
  if s.startsWith("<![CDATA["):
    return 5
  let at = (if s.len > 1 and s[1] == '/': 2 else: 1)
  let name = s.tagName(at)
  if name > at and lower[at ..< name] in blockTags and
      (endsName(name) or s.continuesWith("/>", name)):
    return 6
  if name > at and lower[at ..< name] notin rawTags:
    let stop = s.completeTag
    if stop > 0 and s[stop .. ^1].isBlank:
      return 7

proc closes(line: string, kind: int): bool =
  ## Whether `line` meets the end condition of types 1-5.
  if kind == 1:
    let lower = line.toLowerAscii
    for tag in rawTags:
      if "</" & tag & ">" in lower:
        return true
    false
  else:
    ends[kind] in line

proc parseHtml(p: BlockParser): BlockNode =
  let kind = startKind(p.line)
  if kind == 0 or (kind == 7 and p.interrupting):
    return nil
  let node = HtmlBlock(kind: kind)
  if kind <= 5:
    while not p.eof:
      node.lines.add p.line
      p.advance
      if node.lines[^1].closes(kind):
        break
  else:
    while not p.eof and not p.line.isBlank:
      node.lines.add p.line
      p.advance
  node

proc isComment*(node: HtmlBlock): bool =
  ## Whether `node` is nothing but HTML comments and whitespace.
  if node.kind != 2:
    return false
  let s = node.lines.join("\n")
  var i = 0
  while true:
    i = s.skipSpace(i)
    if i >= s.len:
      return true
    if not s.continuesWith("<!--", i):
      return false
    let close = s.find("-->", i + 2)
    if close < 0:
      return true # unclosed: runs to the end
    i = close + 3

proc hardWrap(line: string, width: int): seq[string] =
  ## `line` cut into rows of at most `width` columns between grapheme
  ## clusters, whitespace kept. An empty line gives one empty row.
  result.add ""
  var w = 0
  for (text, cw) in line.clusters:
    if w > 0 and w + cw > width:
      result.add ""
      w = 0
    result[^1].add text
    w += cw

method layout(node: HtmlBlock, ctx: LayoutCtx): seq[Line] =
  if node.isComment:
    return
  let style = ctx.style("html")
  for line in node.lines:
    for row in line.strip(leading = false).hardWrap(ctx.width):
      result.add (if row.len == 0: @[] else: @[Span(text: row, style: style)])

registerBlock BlockRule(
  name: "html", priority: 70, interruptsParagraph: true, parse: parseHtml
)

defaultStyle("html", Style(fg: Color(kind: ckIndexed, index: 243)))
