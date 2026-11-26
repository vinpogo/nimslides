## Lays out a deck's slides for the terminal.
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

proc renderSlides*(src: string, width: int): seq[Slide] =
  ## The slides of `src` (separated by `---` lines) laid out at `width`
  ## columns, indented by `margin`. Always at least one slide.
  for lines in core.renderSlides(src, max(1, width - margin)):
    var slide: Slide
    for line in lines:
      if line.len == 0:
        slide.lines.add line
      else:
        slide.lines.add Span(text: ' '.repeat(margin)) & line
    result.add slide
