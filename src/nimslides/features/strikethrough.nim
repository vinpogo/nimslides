## GFM strikethrough: `~~text~~` and `~text~`. Opener and closer must be runs
## of the same length, and runs of 3 or more tildes stay literal (core does
## the matching).

import ../core

type Strikethrough* = ref object of InlineNode ## `~a~` or `~~a~~`
  children*: seq[InlineNode]

method spans(node: Strikethrough, ctx: LayoutCtx, base: Style): seq[Span] =
  node.children.spans(ctx, base.merge(ctx.style("strikethrough")))

proc build(count: int, children: seq[InlineNode]): InlineNode =
  Strikethrough(children: children)

registerDelimiter DelimiterRule(
  name: "strikethrough",
  ch: '~',
  intraword: true,
  sameLength: true,
  maxRun: 2,
  build: build,
)

defaultStyle("strikethrough", Style(strikethrough: true))
