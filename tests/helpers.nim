## Helpers for core and feature tests.
##
## Only core is imported here. A feature test imports its own feature
## (`import nimslides/features/<name>`), so it runs with exactly that
## feature registered, whatever other features exist.

import std/[os, sequtils, strutils]
import nimslides/core
export core

proc styled*(md: string, width = 40): seq[Line] =
  ## The laid-out lines of `md` at `width` columns, with styles. There is no
  ## slide margin: column 0 is the first column of content.
  renderDocument(md, width)

proc render*(md: string, width = 40): seq[string] =
  ## The plain text lines of `md` at `width` columns, without the margin.
  ## Blank lines between blocks are "".
  styled(md, width).mapIt(it.plain)

proc styleOf*(md: string, text: string, width = 40): Style =
  ## The style of the first span containing `text`; fails if there is none.
  for line in styled(md, width):
    for span in line:
      if text in span.text:
        return span.style
  raiseAssert "no span contains " & text.escape

proc widths*(md: string, width = 40): seq[int] =
  ## The display width of each laid-out row of `md` at `width` columns, e.g.
  ## `check widths(md, w).allIt(it <= w)`.
  styled(md, width).mapIt(it.displayWidth)

proc parse*(md: string): seq[BlockNode] =
  ## The top-level blocks of `md`, e.g. `check parse("x")[0] of Paragraph`.
  parseDocument(md, newDocCtx())

proc parseInline*(raw: string): seq[InlineNode] =
  ## The inline nodes of `raw`, e.g. a paragraph's text.
  parseInlines(raw, newDocCtx())

proc example*(name: string): string =
  ## The contents of `examples/features/<name>.md`.
  readFile(
    currentSourcePath().parentDir.parentDir / "examples" / "features" / name & ".md"
  )
