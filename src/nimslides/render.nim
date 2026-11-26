## Lays out a slide's text for the terminal.
##
## The renderer returns styled text, not escape codes, so that whatever draws
## it can cut lines anywhere and paint popups on top. `viewer.nim` paints it
## on the terminal; `plain` gives the text alone. Parsing and layout live in
## `core/`, markdown features in `features/`.

import std/strutils
import ./[core, features]
import ./core/types
export types

const margin* = 2 ## columns of space left of the slide

proc renderSlide*(src: string, width: int): Slide =
  ## `src` laid out at `width` columns, indented by `margin`.
  for line in renderDocument(src, max(1, width - margin)):
    if line.len == 0:
      result.lines.add line
    else:
      result.lines.add Span(text: ' '.repeat(margin)) & line
