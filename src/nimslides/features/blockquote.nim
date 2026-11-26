## Block quotes, as in CommonMark: lines starting with `>` (after at most 3
## spaces of indent, one optional space after the `>` is removed), plus lazy
## continuation lines of a paragraph inside the quote. The content is parsed
## as blocks of its own, so quotes nest and hold any other block.
##
## Shown with a `▎ ` bar in front of every row (`blockquote.bar`), the
## content in `blockquote` style layered under the children's own styles.

import ../core

type BlockQuote* = ref object of BlockNode
  children*: seq[BlockNode]

proc quoteContent(line: string, content: var string): bool =
  ## Whether `line` starts with a quote marker; `content` is the rest of the
  ## line after it.
  let indent = line.indentOf
  if indent > 3 or indent >= line.len or line[indent] != '>':
    return false
  var start = indent + 1
  if start < line.len and line[start] == ' ':
    inc start
  content = line[start .. ^1]
  true

method endsInParagraph(node: BlockQuote): bool =
  node.children.endsInParagraph

registerBlock BlockRule(
  name: "blockquote",
  priority: 50,
  interruptsParagraph: true,
  parse: proc(p: BlockParser): BlockNode =
    var content: string
    if not p.line.quoteContent(content):
      return nil
    if p.interrupting: # only say that a quote starts here
      p.advance
      return BlockQuote()
    var inner: seq[string]
    while not p.eof:
      if p.line.quoteContent(content):
        inner.add content
      elif p.isLazy(inner):
        inner.add p.line.lazyLine
      else:
        break
      p.advance
    BlockQuote(children: p.parseBlocks(inner)),
)

defaultStyle("blockquote.bar", Style(fg: indexed(99)))
defaultStyle("blockquote", Style(italic: true, fg: indexed(250)))

method layout(node: BlockQuote, ctx: LayoutCtx): seq[Line] =
  # The bar and its space need 2 columns; very narrow slides drop the space,
  # then the bar, so rows never get wider than `ctx.width`.
  let prefixW =
    if ctx.width >= 3:
      2
    elif ctx.width == 2:
      1
    else:
      0
  let bar = ctx.style("blockquote.bar")
  let quote = ctx.style("blockquote")
  var rows = ctx.renderBlocks(node.children, ctx.width - prefixW)
  if rows.len == 0: # an empty quote still shows its bar
    rows.add @[]
  for row in rows:
    var line: Line
    if prefixW > 0:
      # Empty rows get the bar alone, without a trailing space.
      let text = if prefixW == 2 and row.len > 0: "▎ " else: "▎"
      line.add Span(text: text, style: bar)
    for span in row:
      line.add Span(text: span.text, style: quote.merge(span.style))
    result.add line
