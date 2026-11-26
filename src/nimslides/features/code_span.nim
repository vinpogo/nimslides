## Code spans: `code` between backtick runs of equal length (CommonMark).
##
## The text inside is literal: no escapes, emphasis or other inline syntax.
## The rule runs at the backtick before core's delimiter scanning, so
## `*a `*` b*` is emphasis around a code span, not emphasis ending inside it.

import std/strutils
import ../core

type CodeSpan* = ref object of InlineNode
  text*: string ## the content after line endings and stripping

method spans(node: CodeSpan, ctx: LayoutCtx, base: Style): seq[Span] =
  @[Span(text: node.text, style: base.merge(ctx.style("code_span")))]

proc runEnd(src: string, start: int): int =
  ## The index after the backtick run starting at `start`.
  result = start
  while result < src.len and src[result] == '`':
    inc result

proc content(raw: string): string =
  ## CommonMark: line endings become spaces, then one space is stripped from
  ## each side if both sides have one and it is not all spaces.
  result = raw.replace('\n', ' ')
  if result.len >= 2 and result[0] == ' ' and result[^1] == ' ' and
      result.strip(chars = {' '}).len > 0:
    result = result[1 ..< ^1]

registerInline InlineRule(
  name: "code_span",
  triggers: {'`'},
  priority: 10,
  parse: proc(p: InlineParser): InlineNode =
    let open = runEnd(p.src, p.pos)
    let n = open - p.pos
    var i = open
    while i < p.src.len:
      if p.src[i] != '`':
        inc i
        continue
      let close = runEnd(p.src, i)
      if close - i == n:
        result = CodeSpan(text: content(p.src[open ..< i]))
        p.pos = close
        return
      i = close
    # No closer: the whole run is literal. Taking it here keeps core from
    # trying again at its second backtick with a shorter run.
    result = Text(text: p.src[p.pos ..< open])
    p.pos = open,
)

defaultStyle("code_span", Style(fg: indexed(216), bg: indexed(236)))
