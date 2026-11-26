## GFM tables: a header row, a delimiter row (`---`, `:--`, `:-:`, `--:`) and
## body rows, drawn in a rounded box. Columns shrink and cells wrap when the
## table is wider than the slide.

import std/[math, strutils]
import ../core

const minShrink = 3 ## columns are not shrunk below this while others are wider

type
  Align* = enum
    alNone
    alLeft
    alCenter
    alRight

  GfmTable* = ref object of BlockNode
    aligns*: seq[Align] ## one per column
    header*: seq[string] ## raw inline source of each header cell
    rows*: seq[seq[string]] ## body rows, padded or cut to the column count

proc splitCells(line: string): seq[string] =
  ## The cells of a row: an optional leading and trailing `|` removed, split
  ## at unescaped `|`, `\|` turned into `|`, each cell stripped. Other
  ## backslash escapes stay for the inline parser.
  let s = line.strip
  var i = 0
  if s.len > 0 and s[0] == '|':
    inc i
  var cell = ""
  var trailingPipe = false
  while i < s.len:
    trailingPipe = false
    if s[i] == '\\' and i + 1 < s.len:
      if s[i + 1] == '|':
        cell.add '|'
      else:
        cell.add s[i .. i + 1]
      i += 2
    elif s[i] == '|':
      result.add cell.strip
      cell = ""
      trailingPipe = true
      inc i
    else:
      cell.add s[i]
      inc i
  if not trailingPipe or cell.strip.len > 0:
    result.add cell.strip

proc hasPipe(line: string): bool =
  ## Whether `line` contains an unescaped `|`.
  var i = 0
  while i < line.len:
    if line[i] == '\\':
      i += 2
    elif line[i] == '|':
      return true
    else:
      inc i

proc parseDelimiter(line: string): seq[Align] =
  ## The alignments of a delimiter row, or @[] if `line` is not one.
  for cell in line.splitCells:
    if cell.len == 0 or cell == ":":
      return @[]
    let left = cell[0] == ':'
    let right = cell[^1] == ':'
    let dashes = cell[(if left: 1 else: 0) ..< cell.len - (if right: 1 else: 0)]
    if dashes.len == 0 or not dashes.allCharsInSet({'-'}):
      return @[]
    result.add(
      if left and right:
        alCenter
      elif left:
        alLeft
      elif right:
        alRight
      else:
        alNone
    )

proc normalize(cells: seq[string], n: int): seq[string] =
  ## `cells` padded with empty cells or cut to `n`.
  result = cells
  result.setLen n

proc parseTable(p: BlockParser): BlockNode =
  let head = p.line
  let delim = p.peek(1)
  if indentOf(head) > 3 or indentOf(delim) > 3 or delim.isBlank:
    return nil
  if not (head.hasPipe or delim.hasPipe): # `text` + `---` is a setext heading
    return nil
  let aligns = parseDelimiter(delim)
  let header = head.splitCells
  if aligns.len == 0 or header.len != aligns.len:
    return nil
  let node = GfmTable(aligns: aligns, header: header)
  p.advance 2
  while not p.eof and not p.line.isBlank and not p.interruptsParagraph:
    node.rows.add p.line.splitCells.normalize(aligns.len)
    p.advance
  node

# Layout

proc lineWidth(line: Line): int =
  for span in line:
    result += span.text.displayWidth

proc fitLine(line: Line, width: int): Line =
  ## `line` cut to at most `width` columns between grapheme clusters; only
  ## needed when a cluster is wider than its column.
  var w = 0
  for span in line:
    var text = ""
    for (c, cw) in span.text.clusters:
      if w + cw > width:
        break
      text.add c
      w += cw
    if text.len > 0:
      result.add Span(text: text, style: span.style)
    if text.len < span.text.len:
      break

proc cellLines(spans: seq[Span], width: int): seq[Line] =
  ## A cell's content wrapped to `width` columns; at least one line.
  for line in wrap(spans, width):
    result.add line.fitLine(width)
  if result.len == 0:
    result.add @[]

proc aligned(line: Line, width: int, align: Align, style: Style): Line =
  ## `line` padded to `width` columns in `style`, as `align` says.
  let fill = max(0, width - line.lineWidth)
  let left =
    case align
    of alCenter:
      fill div 2
    of alRight:
      fill
    else:
      0
  if left > 0:
    result.add Span(text: ' '.repeat(left), style: style)
  result.add line
  if fill - left > 0:
    result.add Span(text: ' '.repeat(fill - left), style: style)

proc columnWidths(natural: seq[int], available: int): seq[int] =
  ## Natural widths, with the widest column shrunk one step at a time until
  ## the table fits: first down to `minShrink`, then down to 1.
  result = natural
  let frame = 3 * natural.len + 1 # "│ " before each cell, " " after, final "│"
  for floor in [minShrink, 1]:
    while frame + sum(result) > available:
      var widest = 0
      for i, w in result:
        if w > result[widest]:
          widest = i
      if result[widest] <= floor:
        break
      dec result[widest]

proc border(widths: seq[int], left, mid, right: string, style: Style): Line =
  var s = left
  for i, w in widths:
    if i > 0:
      s.add mid
    s.add "─".repeat(w + 2)
  s.add right
  @[Span(text: s, style: style)]

method layout(node: GfmTable, ctx: LayoutCtx): seq[Line] =
  let borderStyle = ctx.style("table.border")
  let headStyle = ctx.style("table.header")
  let cellStyle = ctx.style("table.cell")
  let n = node.aligns.len

  var cells: seq[seq[seq[Span]]] # rows of cells of spans; row 0 is the header
  cells.add @[]
  for raw in node.header:
    cells[0].add ctx.inlines(raw, headStyle)
  for row in node.rows:
    cells.add @[]
    for raw in row:
      cells[^1].add ctx.inlines(raw, cellStyle)

  var natural = newSeq[int](n)
  for row in cells:
    for i, spans in row:
      for line in wrap(spans, high(int) div 2):
        natural[i] = max(natural[i], line.lineWidth)
  for w in natural.mitems:
    w = max(1, w)
  let widths = columnWidths(natural, ctx.width)

  proc rowLines(row: seq[seq[Span]], style: Style): seq[Line] =
    var wrapped: seq[seq[Line]]
    var height = 1
    for i, spans in row:
      wrapped.add cellLines(spans, widths[i])
      height = max(height, wrapped[^1].len)
    for r in 0 ..< height:
      var line: Line = @[Span(text: "│", style: borderStyle)]
      for i in 0 ..< n:
        let content =
          if r < wrapped[i].len:
            wrapped[i][r]
          else:
            @[]
        line.add Span(text: " ", style: style)
        line.add content.aligned(widths[i], node.aligns[i], style)
        line.add Span(text: " ", style: style)
        line.add Span(text: "│", style: borderStyle)
      result.add line

  var lines: seq[Line]
  lines.add border(widths, "╭", "┬", "╮", borderStyle)
  lines.add rowLines(cells[0], headStyle)
  lines.add border(widths, "├", "┼", "┤", borderStyle)
  for row in cells[1 .. ^1]:
    lines.add rowLines(row, cellStyle)
  lines.add border(widths, "╰", "┴", "╯", borderStyle)

  for line in lines: # only when even 1-column cells do not fit
    result.add line.fitLine(ctx.width)

registerBlock BlockRule(
  name: "table", priority: 80, interruptsParagraph: false, parse: parseTable
)

defaultStyle("table.border", Style(fg: Color(kind: ckIndexed, index: 240)))
defaultStyle("table.header", Style(bold: true, fg: Color(kind: ckIndexed, index: 81)))
defaultStyle("table.cell", Style())
