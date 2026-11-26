## Layout: word wrapping, inline rendering and stacking of blocks.

import std/strutils
import ./[ast, inlines, registry, types, width]

proc displayWidth*(line: Line): int =
  ## Columns `line` takes in the terminal.
  line.plain.displayWidth

proc fit*(line: Line, width: int): Line =
  ## The leading grapheme clusters of `line` that fit in `width` columns,
  ## styles kept; for rows that must not get wider than the slide.
  var left = width
  for span in line:
    let (text, w) = span.text.fit(left)
    if text.len > 0:
      result.add Span(text: text, style: span.style)
    if text.len < span.text.len:
      break
    left -= w

proc newLayoutCtx*(width: int, doc: DocCtx): LayoutCtx =
  LayoutCtx(width: max(1, width), doc: doc)

proc add(line: var Line, text: string, style: Style) =
  ## Appends to the last span when the style is the same.
  if text.len == 0:
    return
  if line.len > 0 and line[^1].style == style:
    line[^1].text.add text
  else:
    line.add Span(text: text, style: style)

proc wrap*(spans: seq[Span], width: int): seq[Line] =
  ## Greedy word wrap of `spans` to `width` columns. Words break at spaces;
  ## a word wider than a line is split between grapheme clusters, never
  ## inside one. Spaces between words on a line are kept, spaces at the
  ## start and end of lines are dropped. A "\n" in a span forces a break.
  let width = max(1, width)
  var line: Line
  var lineW = 0
  var gap: seq[Span] # spaces since the last word
  var gapW = 0
  var word: seq[Span] # clusters of the word being read
  var wordW = 0

  template newLine() =
    result.add line
    line = @[]
    lineW = 0

  template placeWord() =
    if wordW > 0:
      if lineW > 0 and lineW + gapW + wordW <= width:
        for s in gap:
          line.add s.text, s.style
        lineW += gapW
      elif lineW > 0:
        newLine()
      if lineW + wordW <= width:
        for s in word:
          line.add s.text, s.style
        lineW += wordW
      else: # longer than a line: split it
        for s in word:
          for (text, w) in s.text.clusters:
            if lineW > 0 and lineW + w > width:
              newLine()
            line.add text, s.style
            lineW += w
    word.setLen 0
    wordW = 0
    gap.setLen 0
    gapW = 0

  for span in spans:
    for (text, w) in span.text.clusters:
      case text
      of "\n":
        placeWord()
        newLine()
      of " ":
        if wordW > 0:
          placeWord()
        gap.add Span(text: text, style: span.style)
        gapW += w
      else:
        word.add Span(text: text, style: span.style)
        wordW += w
  placeWord()
  if line.len > 0:
    result.add line

proc inlines*(ctx: LayoutCtx, raw: string, base: Style): seq[Span] =
  ## Parses `raw` as inline markdown and renders it on top of `base`.
  parseInlines(raw, ctx.doc).spans(ctx, base)

proc layoutBlocks*(ctx: LayoutCtx, blocks: seq[BlockNode], gap = 1): seq[Line] =
  ## `blocks` laid out at `ctx.width`, with `gap` blank lines between them.
  ## Blocks without lines (e.g. hidden comments) take no space.
  for b in blocks:
    let lines = b.layout(ctx)
    if lines.len == 0:
      continue
    if result.len > 0:
      for _ in 1 .. gap:
        result.add @[]
    result.add lines

proc renderBlocks*(
    ctx: LayoutCtx, children: seq[BlockNode], width: int, gap = 1
): seq[Line] =
  ## For containers: lays out `children` at `width` columns, one level
  ## deeper. Use `gap = 0` for tight content such as tight list items.
  var child = ctx
  child.width = max(1, width)
  child.depth += 1
  child.layoutBlocks(children, gap)

proc filledRow*(ctx: LayoutCtx, style: Style): Line =
  ## An empty row across the full width in `style`, e.g. a card's edge.
  @[Span(text: ' '.repeat(ctx.width), style: style)]

proc literalRows*(
    ctx: LayoutCtx, lines: seq[string], style: Style, lead = 0
): seq[Line] =
  ## Literal text such as code: each line hard-wrapped, indented by `lead`
  ## columns and padded to exactly `ctx.width`, all in `style`, so the text
  ## sits on a solid card. `lead` shrinks to keep a column for the text.
  let lead = max(0, min(lead, ctx.width - 1))
  for line in lines:
    for row in line.hardWrap(ctx.width - lead):
      let fill = max(0, ctx.width - lead - row.width)
      result.add @[
        Span(text: ' '.repeat(lead) & row.text & ' '.repeat(fill), style: style)
      ]

defaultStyle("paragraph", Style())

method layout*(node: Paragraph, ctx: LayoutCtx): seq[Line] =
  wrap(ctx.inlines(node.raw, ctx.style("paragraph")), ctx.width)
