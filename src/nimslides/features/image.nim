## Images: `![alt](url "title")`, `![alt][label]`, `![alt][]` and `![alt]`.
##
## A terminal can't show the picture here, so an image renders as a
## placeholder: `▨ alt (url)`. The alt text is parsed as inlines and then
## flattened to plain text, as CommonMark does for HTML's `alt` attribute.
## The parsing of the brackets and the tail is core's (`core/links.nim`).

import std/strutils
import ../core

type Image* = ref object of InlineNode
  url*: string
  title*: string ## kept for later use; not shown
  alt*: seq[InlineNode] ## the parsed alt text

const
  marker = "▨"
  glue = " " ## no-break space: keeps the marker on the alt's first line

proc altText(nodes: seq[InlineNode], ctx: LayoutCtx): string =
  ## The alt text as plain text. A nested image contributes only its own alt
  ## text (`![a ![b](x)](y)` has alt "a b"); other nodes their rendered text.
  for node in nodes:
    if node of Image:
      result.add Image(node).alt.altText(ctx)
    else:
      for span in node.spans(ctx, Style()):
        result.add span.text.replace('\n', ' ')

method spans(node: Image, ctx: LayoutCtx, base: Style): seq[Span] =
  let alt = node.alt.altText(ctx)
  let look = base.merge(ctx.style("image"))
  result.add Span(text: (if alt.len > 0: marker & glue & alt else: marker), style: look)
  if node.url.len > 0:
    result.add Span(text: " ", style: base)
    result.add Span(
      text: "(" & node.url & ")", style: base.merge(ctx.style("image.url"))
    )

registerInline InlineRule(
  name: "image",
  triggers: {'!'},
  priority: 40,
  parse: proc(p: InlineParser): InlineNode =
    # nil keeps a lone `!` (or `![` without a valid tail) as text; core then
    # goes on at the next character, so `![foo]` can still become `!` + link.
    if p.peek(1) != '[':
      return
    let text = linkText(p.src, p.pos + 1)
    let target = p.parseLinkTail(text)
    if target.found:
      result =
        Image(url: target.url, title: target.title, alt: p.parseInlines(text.text))
      p.pos = target.stop
  ,
)

defaultStyle("image", Style(italic: true, fg: Color(kind: ckIndexed, index: 176)))
defaultStyle("image.url", Style(fg: Color(kind: ckIndexed, index: 243)))
