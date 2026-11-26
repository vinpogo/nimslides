## Thematic breaks, as in CommonMark: a line of three or more `*`, `-` or
## `_` (all the same character), optionally with spaces between them, after
## at most 3 spaces of indent. Shown as a `─` rule across the full width
## (`thematic_break`).

import std/strutils
import ../core

type ThematicBreak* = ref object of BlockNode

method layout(node: ThematicBreak, ctx: LayoutCtx): seq[Line] =
  @[@[Span(text: "─".repeat(max(ctx.width, 0)), style: ctx.style("thematic_break"))]]

proc isThematicBreak*(line: string): bool =
  ## Whether `line` (tabs already expanded) is a thematic break.
  if line.indentOf > 3:
    return false
  var mark = '\0'
  var count = 0
  for c in line:
    case c
    of ' ':
      discard
    of '*', '-', '_':
      if mark == '\0':
        mark = c
      elif c != mark:
        return false
      inc count
    else:
      return false
  count >= 3

registerBlock BlockRule(
  name: "thematic_break",
  priority: 40,
  interruptsParagraph: true,
  parse: proc(p: BlockParser): BlockNode =
    if p.line.isThematicBreak:
      result = ThematicBreak()
      p.advance
  ,
)

defaultStyle("thematic_break", Style(fg: indexed(240)))
