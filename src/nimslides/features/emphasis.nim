## Emphasis and strong emphasis: `*em*`, `_em_`, `**strong**`, `__strong__`,
## `***both***`, with CommonMark's delimiter rules (core does the matching).

import ../core

type
  Emphasis* = ref object of InlineNode ## `*a*` or `_a_`, italic
    children*: seq[InlineNode]

  Strong* = ref object of InlineNode ## `**a**` or `__a__`, bold
    children*: seq[InlineNode]

method spans(node: Emphasis, ctx: LayoutCtx, base: Style): seq[Span] =
  node.children.spans(ctx, base.merge(ctx.style("emphasis")))

method spans(node: Strong, ctx: LayoutCtx, base: Style): seq[Span] =
  node.children.spans(ctx, base.merge(ctx.style("strong")))

proc build(count: int, children: seq[InlineNode]): InlineNode =
  ## core matches 1 or 2 delimiters at a time; `***a***` nests both.
  if count == 1:
    Emphasis(children: children)
  else:
    Strong(children: children)

registerDelimiter DelimiterRule(
  name: "emphasis.star", ch: '*', intraword: true, ruleOf3: true, build: build
)

registerDelimiter DelimiterRule(
  name: "emphasis.underscore", ch: '_', intraword: false, ruleOf3: true, build: build
)

defaultStyle("emphasis", Style(italic: true))
defaultStyle("strong", Style(bold: true))
