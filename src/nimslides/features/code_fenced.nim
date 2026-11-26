## Fenced code blocks: ``` or ~~~ fences, shown as a shaded card with the
## language in its top row. The content is literal and hard-wrapped.

import std/strutils
import ../core

const pad = 2 ## columns of shading left of the code, and right of the language

type FencedCode* = ref object of BlockNode
  info*: string ## the info string, backslash escapes processed
  lang*: string ## its first word, "" if none; kept for syntax highlighting
  lines*: seq[string] ## the content lines, fence indentation removed

proc fenceAt(line: string): tuple[indent: int, ch: char, len: int] =
  ## The fence that `line` starts with, or `len == 0` if none.
  let indent = indentOf(line)
  if indent > 3 or indent >= line.len or line[indent] notin {'`', '~'}:
    return
  let ch = line[indent]
  var i = indent
  while i < line.len and line[i] == ch:
    inc i
  if i - indent >= 3:
    result = (indent, ch, i - indent)

proc closes(line: string, ch: char, minLen: int): bool =
  ## Whether `line` is a closing fence of `ch`, at least `minLen` long.
  let f = fenceAt(line)
  f.len >= minLen and f.ch == ch and line[f.indent + f.len .. ^1].isBlank

proc dedent(line: string, n: int): string =
  ## `line` without up to `n` leading spaces.
  line[min(n, indentOf(line)) .. ^1]

proc parseFence(p: BlockParser): BlockNode =
  let open = fenceAt(p.line)
  if open.len == 0:
    return nil
  let info = p.line[open.indent + open.len .. ^1].strip
  if open.ch == '`' and '`' in info:
    return nil
  let words = info.splitWhitespace
  let node = FencedCode(
    info: info.resolveEscapes,
    lang:
      if words.len > 0:
        words[0].resolveEscapes
      else:
        "",
  )
  p.advance
  while not p.eof and not p.line.closes(open.ch, open.len):
    node.lines.add p.line.dedent(open.indent)
    p.advance
  p.advance # past the closing fence; unclosed fences run to the end
  node

method layout(node: FencedCode, ctx: LayoutCtx): seq[Line] =
  let shade = ctx.style("code_fenced")
  let lead = min(pad, ctx.width - 1) # keep at least a column for the code
  let empty = @[Span(text: ' '.repeat(ctx.width), style: shade)]

  let lang = node.lang.fit(max(0, ctx.width - pad))
  if lang.width == 0:
    result.add empty
  else:
    let right = min(pad, ctx.width - lang.width)
    let left = ctx.width - lang.width - right
    var top: Line
    if left > 0:
      top.add Span(text: ' '.repeat(left), style: shade)
    top.add Span(text: lang.text, style: shade.merge(ctx.style("code_fenced.lang")))
    top.add Span(text: ' '.repeat(right), style: shade)
    result.add top

  for line in node.lines:
    for row in line.hardWrap(ctx.width - lead):
      let fill = max(0, ctx.width - lead - row.width)
      result.add @[
        Span(text: ' '.repeat(lead) & row.text & ' '.repeat(fill), style: shade)
      ]
  result.add empty

registerBlock BlockRule(
  name: "code_fenced", priority: 20, interruptsParagraph: true, parse: parseFence
)

defaultStyle(
  "code_fenced",
  Style(fg: Color(kind: ckIndexed, index: 252), bg: Color(kind: ckIndexed, index: 235)),
)
defaultStyle(
  "code_fenced.lang",
  Style(
    italic: true,
    fg: Color(kind: ckIndexed, index: 243),
    bg: Color(kind: ckIndexed, index: 235),
  ),
)
