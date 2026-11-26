## Lists, as in CommonMark, plus GFM task items.
##
## Bullet lists (`-`, `+`, `*`) and ordered lists (`1.`, `1)`, up to 9
## digits). An item's content is every following line indented to its
## content column, blank lines, and lazy continuation lines of a paragraph.
## A different bullet character or delimiter starts a new list. A list is
## loose when its items are separated by blank lines, or when an item has a
## blank line between two of its blocks; loose lists get a blank row between
## items.
##
## Shown with a hanging indent: `•` `◦` `▪` `‣` by list nesting depth
## (`list.bullet`), right-aligned numbers (`list.number`), and for task items
## `✔` (`list.done`) or `☐` (`list.open`) in place of the bullet.

import std/strutils
import ../core

type
  Task* = enum
    taskNone
    taskOpen
    taskDone

  ListItem* = object
    children*: seq[BlockNode]
    task*: Task

  List* = ref object of BlockNode
    ordered*: bool
    bullet*: char ## `-`, `+` or `*`; bullet lists only
    delimiter*: char ## `.` or `)`; ordered lists only
    start*: int ## the first number; ordered lists only
    loose*: bool
    items*: seq[ListItem]

  ListState = ref object of RootObj
    depth: int ## list nesting while laying out, for the bullet glyph

  Marker = object
    ok: bool
    ordered: bool
    ch: char ## the bullet, or the delimiter of an ordered marker
    number: int
    content: int ## the content column of the item
    empty: bool ## nothing after the marker
    text: string ## the first line's content (may keep 4+ spaces: indented code)

const
  priority = 60
  bullets = ["•", "◦", "▪", "‣"]

proc parseMarker(line: string): Marker =
  ## The list marker that `line` starts with, if any.
  let indent = line.indentOf
  if indent > 3 or indent >= line.len:
    return
  var i = indent
  if line[i] in {'-', '+', '*'}:
    result.ch = line[i]
    inc i
  elif line[i] in Digits:
    while i < line.len and line[i] in Digits:
      inc i
    if i - indent > 9 or i >= line.len or line[i] notin {'.', ')'}:
      return
    result.ordered = true
    result.number = parseInt(line[indent ..< i])
    result.ch = line[i]
    inc i
  else:
    return
  if i < line.len and line[i] != ' ':
    return
  var spaces = 0
  while i + spaces < line.len and line[i + spaces] == ' ':
    inc spaces
  result.ok = true
  if i + spaces >= line.len: # only spaces after the marker
    result.empty = true
    result.content = i + 1
  elif spaces >= 5: # content is indented code: it starts one space in
    result.content = i + 1
    result.text = line[i + 1 .. ^1]
  else:
    result.content = i + spaces
    result.text = line[i + spaces .. ^1]

proc sameList(a, b: Marker): bool =
  a.ordered == b.ordered and a.ch == b.ch

proc itemStart(p: BlockParser): Marker =
  ## The marker of a list item starting on the current line, if any.
  result = p.line.parseMarker
  if result.ok and p.claimedBefore(priority):
    result.ok = false

method endsInParagraph(node: List): bool =
  node.items.len > 0 and node.items[^1].children.endsInParagraph

proc blankBetweenBlocks(lines: seq[string], count: int): bool =
  ## Whether a blank line in `lines` separates two of its `count` blocks
  ## directly (not one inside fenced code or a nested list): splitting the
  ## lines there keeps the same blocks.
  for i in 1 ..< lines.len:
    if lines[i].isBlank and not lines[i - 1].isBlank:
      var next = i
      while next < lines.len and lines[next].isBlank:
        inc next
      if next < lines.len and
          scratchBlocks(lines[0 ..< i]).len + scratchBlocks(lines[next .. ^1]).len ==
          count:
        return true

proc parseItem(p: BlockParser, m: Marker): seq[string] =
  ## Takes the item starting at the current line; returns its content lines
  ## with the indent removed. Blank lines after the item are left.
  var lines: seq[string]
  if not m.empty:
    lines.add m.text
  p.advance
  while not p.eof:
    let line = p.line
    if line.isBlank:
      if lines.len == 0: # an item starts with at most one blank line
        break
      lines.add ""
    elif line.indentOf >= m.content:
      lines.add line[m.content .. ^1]
    elif p.itemStart.ok or not p.isLazy(lines):
      break
    else:
      lines.add line.lazyLine
    p.advance
  while lines.len > 0 and lines[^1].isBlank:
    lines.setLen lines.len - 1
    p.pos -= 1

  lines

proc taskOf(item: var ListItem) =
  ## A GFM task marker at the start of the first paragraph: `[ ]`, `[x]`,
  ## `[X]` followed by a space.
  if item.children.len == 0 or not (item.children[0] of Paragraph):
    return
  let para = Paragraph(item.children[0])
  if para.raw.len < 4 or para.raw[0] != '[' or para.raw[2] != ']' or
      para.raw[3] notin {' ', '\n'}:
    return
  case para.raw[1]
  of ' ':
    item.task = taskOpen
  of 'x', 'X':
    item.task = taskDone
  else:
    return
  let rest = para.raw[4 .. ^1].strip(trailing = false)
  if rest.len == 0:
    item.children.delete 0
  else:
    item.children[0] = Paragraph(raw: rest)

proc parseList(p: BlockParser): BlockNode =
  let first = p.itemStart
  if not first.ok:
    return nil
  if p.interrupting: # only say whether a list may start here
    if first.empty or (first.ordered and first.number != 1):
      return nil
    p.advance
    return List()

  let list = List(
    ordered: first.ordered,
    bullet: (if first.ordered: '\0' else: first.ch),
    delimiter: (if first.ordered: first.ch else: '\0'),
    start: first.number,
  )
  var m = first
  while true:
    let lines = p.parseItem(m)
    var item = ListItem(children: p.parseBlocks(lines))
    if item.children.len > 1 and lines.blankBetweenBlocks(scratchBlocks(lines).len):
      list.loose = true
    item.taskOf
    list.items.add item

    let afterItem = p.pos
    while not p.eof and p.line.isBlank:
      p.advance
    if p.eof:
      p.pos = afterItem
      break
    m = p.itemStart
    if not (m.ok and m.sameList(first)):
      p.pos = afterItem
      break
    if p.pos > afterItem:
      list.loose = true

  list

method layout(node: List, ctx: LayoutCtx): seq[Line] =
  let state = ctx.doc.state("list", ListState)
  let level = state.depth
  let numWidth =
    if node.ordered:
      max(($node.start).len, ($(node.start + node.items.len - 1)).len)
    else:
      0
  for i, item in node.items:
    var marker: seq[Span]
    if node.ordered:
      marker.add Span(
        text: align($(node.start + i), numWidth) & $node.delimiter,
        style: ctx.style("list.number"),
      )
    case item.task
    of taskNone:
      if not node.ordered:
        marker.add Span(
          text: bullets[level mod bullets.len], style: ctx.style("list.bullet")
        )
    of taskOpen, taskDone:
      if marker.len > 0:
        marker.add Span(text: " ")
      marker.add(
        if item.task == taskDone:
          Span(text: "✔", style: ctx.style("list.done"))
        else:
          Span(text: "☐", style: ctx.style("list.open"))
      )
    let indent = marker.displayWidth + 1

    if node.loose and i > 0:
      result.add @[]
    inc state.depth
    var rows: seq[Line]
    try:
      if ctx.width - indent < 1: # too narrow for a hanging indent
        rows = ctx.renderBlocks(item.children, ctx.width, gap = ord(node.loose))
        result.add rows
        continue
      rows = ctx.renderBlocks(item.children, ctx.width - indent, gap = ord(node.loose))
    finally:
      dec state.depth
    if rows.len == 0:
      result.add marker
      continue
    for r, row in rows:
      var line: Line
      if r == 0:
        line = marker
        line.add Span(text: " ")
      elif row.len > 0:
        line.add Span(text: ' '.repeat(indent))
      line.add row
      result.add line

registerBlock BlockRule(
  name: "list", priority: priority, interruptsParagraph: true, parse: parseList
)

defaultStyle("list.bullet", Style(fg: indexed(205)))
defaultStyle("list.number", Style(fg: indexed(205)))
defaultStyle("list.done", Style(fg: indexed(114)))
defaultStyle("list.open", Style(fg: indexed(244)))
