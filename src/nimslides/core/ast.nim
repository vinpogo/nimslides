## Open node types and the contexts they are parsed and laid out with.
##
## Features add node kinds by inheriting from `BlockNode` or `InlineNode` and
## overriding `layout` or `spans`. Core never needs to know them.

import std/tables
import ./types

type
  DocCtx* = ref object
    ## Document-wide state shared by parsing and layout, e.g. link reference
    ## definitions. Each feature keeps its state under its own name; see
    ## `state`.
    data: Table[string, RootRef]

  LayoutCtx* = object
    ## What a node is laid out with. Containers pass a copy with a smaller
    ## `width` and a deeper `depth` to their children (`renderBlocks`).
    width*: int ## columns available to the node; always at least 1
    depth*: int ## container nesting: 0 at the top of the slide
    doc*: DocCtx
    theme*: Table[string, Style] ## overrides of default styles, by key

  BlockNode* = ref object of RootObj ## a block: paragraph, heading, list, ...
  InlineNode* = ref object of RootObj ## a piece of inline content

  Paragraph* = ref object of BlockNode ## core's fallback block
    raw*: string ## the text, lines joined by "\n"; inlines are parsed in layout

  Text* = ref object of InlineNode ## literal text
    text*: string

proc newText*(text: string): InlineNode =
  ## A `Text` node typed as `InlineNode`, e.g. for `@[newText("a")]`.
  Text(text: text)

proc newDocCtx*(): DocCtx =
  DocCtx()

proc state*[T: ref RootObj](doc: DocCtx, key: string, _: typedesc[T]): T =
  ## The document state stored under `key` (by convention the feature name),
  ## created with `T()` on first use.
  if key notin doc.data:
    doc.data[key] = T()
  T(doc.data[key])

method layout*(node: BlockNode, ctx: LayoutCtx): seq[Line] {.base.} =
  ## The lines of `node`, at most `ctx.width` columns wide. Every block kind
  ## overrides this.
  raiseAssert "a BlockNode subtype does not override `layout`"

method spans*(node: InlineNode, ctx: LayoutCtx, base: Style): seq[Span] {.base.} =
  ## The styled text of `node` on top of `base`, which carries the style of
  ## the enclosing nodes. Spans may contain "\n" to force a line break.
  ## Every inline kind overrides this.
  raiseAssert "an InlineNode subtype does not override `spans`"

method spans*(node: Text, ctx: LayoutCtx, base: Style): seq[Span] =
  @[Span(text: node.text, style: base)]

proc spans*(nodes: seq[InlineNode], ctx: LayoutCtx, base: Style): seq[Span] =
  ## The spans of `nodes` in order; for nodes that wrap children.
  for node in nodes:
    result.add node.spans(ctx, base)

method plainText*(node: InlineNode, ctx: LayoutCtx): string {.base.} =
  ## `node` as plain text, e.g. for an image's alt text. By default the text
  ## of its spans, line breaks as spaces. Override it when the spans show
  ## more than the content (a link's url).
  for span in node.spans(ctx, Style()):
    for ch in span.text:
      result.add(if ch == '\n': ' ' else: ch)

proc plainText*(nodes: seq[InlineNode], ctx: LayoutCtx): string =
  ## The plain text of `nodes` in order.
  for node in nodes:
    result.add node.plainText(ctx)
