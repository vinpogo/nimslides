## Indented code blocks: lines indented 4 or more spaces, shown as the same
## shaded card as fenced code, without a language. The content is literal
## and hard-wrapped.

import ../core

const
  indent = 4 ## columns of indentation that make a code line
  pad = 2 ## columns of shading left of the code

type IndentedCode* = ref object of BlockNode
  lines*: seq[string] ## the content lines, the first 4 columns removed

proc parseIndented(p: BlockParser): BlockNode =
  if p.line.isBlank or indentOf(p.line) < indent:
    return nil
  let node = IndentedCode()
  var last = p.pos # the last non-blank line taken
  while not p.eof and (p.line.isBlank or indentOf(p.line) >= indent):
    # blank lines keep whatever lies beyond the first 4 columns
    node.lines.add p.line[min(indent, p.line.len) .. ^1]
    if not p.line.isBlank:
      last = p.pos
    p.advance
  # trailing blank lines are not part of the block
  node.lines.setLen(node.lines.len - (p.pos - 1 - last))
  p.pos = last + 1
  node

method layout(node: IndentedCode, ctx: LayoutCtx): seq[Line] =
  let shade = ctx.style("code_indented")
  result.add ctx.filledRow(shade)
  result.add ctx.literalRows(node.lines, shade, lead = pad)
  result.add ctx.filledRow(shade)

registerBlock BlockRule(
  name: "code_indented", priority: 10, interruptsParagraph: false, parse: parseIndented
)

defaultStyle("code_indented", Style(fg: indexed(252), bg: indexed(235)))
