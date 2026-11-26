## Headings: ATX (`# Title` … `###### Title`) and setext (a paragraph
## underlined with `===` for level 1 or `---` for level 2), as in CommonMark.
##
## The text is shown without the markers, styled per level (`heading.1` …
## `heading.6`). Levels 1 and 2 get a rule row under the text, as wide as
## its widest line (`heading.1.rule`, `heading.2.rule`).

import std/strutils
import ../core

type Heading* = ref object of BlockNode
  level*: int ## 1 to 6
  raw*: string ## the text, without markers; inlines are parsed in layout

const ruleChars: array[1 .. 2, string] = ["━", "─"] # the rule row of h1 and h2

method layout(node: Heading, ctx: LayoutCtx): seq[Line] =
  let key = "heading." & $node.level
  result = wrap(ctx.inlines(node.raw, ctx.style(key)), ctx.width)
  if node.level in ruleChars.low .. ruleChars.high and result.len > 0:
    var widest = 0
    for line in result:
      widest = max(widest, line.plain.displayWidth)
    result.add @[
      Span(text: ruleChars[node.level].repeat(widest), style: ctx.style(key & ".rule"))
    ]

proc atxHeading(line: string): Heading =
  ## The heading on `line`, or nil if it is not an ATX heading.
  let indent = line.indentOf
  if indent > 3:
    return nil
  var i = indent
  while i < line.len and line[i] == '#':
    inc i
  let level = i - indent
  if level notin 1 .. 6 or (i < line.len and line[i] notin {' ', '\t'}):
    return nil
  var text = line[i .. ^1].strip
  # An optional closing sequence: `#`s alone or after a space.
  var j = text.len
  while j > 0 and text[j - 1] == '#':
    dec j
  if j == 0:
    text = ""
  elif text[j - 1] in {' ', '\t'}:
    text = text[0 ..< j].strip(leading = false)
  Heading(level: level, raw: text)

proc setextLevel(line: string): int =
  ## 1 for a `===` underline, 2 for `---`, else 0.
  if line.indentOf > 3:
    return 0
  let mark = line.strip
  if mark.len == 0:
    return 0
  if mark.allCharsInSet({'='}):
    1
  elif mark.allCharsInSet({'-'}):
    2
  else:
    0

registerBlock BlockRule(
  name: "heading",
  priority: 30,
  interruptsParagraph: true,
  parse: proc(p: BlockParser): BlockNode =
    result = atxHeading(p.line)
    if result != nil:
      p.advance
  ,
)

registerParagraphCloser ParagraphCloser(
  name: "heading",
  priority: 10,
  close: proc(p: BlockParser): ParagraphBuild =
    let level = setextLevel(p.line)
    if level > 0:
      p.advance
      result = proc(lines: seq[string]): BlockNode =
        Heading(level: level, raw: lines.join("\n").strip(leading = false))
  ,
)

defaultStyle("heading.1", Style(bold: true, fg: Color(kind: ckIndexed, index: 205)))
defaultStyle("heading.2", Style(bold: true, fg: Color(kind: ckIndexed, index: 81)))
defaultStyle("heading.3", Style(bold: true, fg: Color(kind: ckIndexed, index: 221)))
defaultStyle("heading.4", Style(bold: true, fg: Color(kind: ckIndexed, index: 114)))
defaultStyle("heading.5", Style(bold: true, fg: Color(kind: ckIndexed, index: 147)))
defaultStyle(
  "heading.6", Style(bold: true, italic: true, fg: Color(kind: ckIndexed, index: 245))
)
defaultStyle("heading.1.rule", Style(fg: Color(kind: ckIndexed, index: 205)))
defaultStyle("heading.2.rule", Style(fg: Color(kind: ckIndexed, index: 81)))
