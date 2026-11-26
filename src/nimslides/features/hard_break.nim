## Hard line breaks (CommonMark): two or more spaces, or a backslash, right
## before a line ending inside a paragraph force a line break there.
##
## Core drops trailing spaces before a soft break, so the space form is
## matched at its first space. Blocks strip their trailing whitespace, so a
## hard break at the end of a paragraph or heading never reaches this rule,
## and a lone `\` at the end stays literal.

import ../core

type HardBreak* = ref object of InlineNode ## renders as a forced line break

method spans(node: HardBreak, ctx: LayoutCtx, base: Style): seq[Span] =
  @[Span(text: "\n", style: base)]

proc afterBreak(p: InlineParser, newline: int): int =
  ## The index after the line ending at `newline` and the next line's
  ## leading spaces, which CommonMark ignores.
  result = newline + 1
  while result < p.src.len and p.src[result] in {' ', '\t'}:
    inc result

registerInline InlineRule(
  name: "hard_break",
  triggers: {' ', '\\'},
  priority: 60,
  parse: proc(p: InlineParser): InlineNode =
    if p.peek == '\\':
      if p.peek(1) == '\n': # otherwise core's escape handles the backslash
        result = HardBreak()
        p.pos = p.afterBreak(p.pos + 1)
      return
    var i = p.pos
    while i < p.src.len and p.src[i] == ' ':
      inc i
    if i < p.src.len and p.src[i] == '\n':
      if i - p.pos >= 2:
        result = HardBreak()
        p.pos = p.afterBreak(i)
      # A single space before a line ending: core's soft break drops it.
    else:
      # Spaces inside a line are text. Taking the whole run here keeps core
      # from trying again at each of its spaces.
      result = Text(text: p.src[p.pos ..< i])
      p.pos = i,
)
