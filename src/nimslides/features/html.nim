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
  let name = s.tagNameEnd(at)
  if name > at and lower[at ..< name] in blockTags and
      (endsName(name) or s.continuesWith("/>", name)):
    return 6
  if name > at and lower[at ..< name] notin rawTags:
    let stop = s.tagEnd(0)
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
    i = s.skip(i, htmlSpace)
    if i >= s.len:
      return true
    if not s.continuesWith("<!--", i):
      return false
    let close = s.find("-->", i + 2)
    if close < 0:
      return true # unclosed: runs to the end
    i = close + 3

method layout(node: HtmlBlock, ctx: LayoutCtx): seq[Line] =
  if node.isComment:
    return
  let style = ctx.style("html")
  for line in node.lines:
    for row in line.strip(leading = false).hardWrap(ctx.width):
      result.add (if row.text.len == 0: @[]
      else: @[Span(text: row.text, style: style)])

registerBlock BlockRule(
  name: "html", priority: 70, interruptsParagraph: true, parse: parseHtml
)

defaultStyle("html", Style(fg: indexed(243)))
