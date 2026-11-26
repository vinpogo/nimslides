## Lays out a deck's slides for the terminal.
##
## The renderer returns styled text, not escape codes, so that whatever draws
## it can cut lines anywhere and paint popups on top. `viewer.nim` paints it
## on the terminal; `plain` gives the text alone. Parsing and layout live in
## `core/`, markdown features in `features/`.

import std/[strutils, tables]
import ./[core, features]
import ./core/types
export types, tables

const margin* = 2 ## columns of space left of the slide

type Theme* = Table[string, Style] ## style overrides by key; see `theme.nim`

defaultStyle("slide", Style()) # the base style and background of every slide
defaultStyle("footer", Style()) # the bottom row of a deck, over `slide`
defaultStyle("footer.counter", Style(dim: true)) # the "3/7" on it, over `footer`

proc themed*(theme: Theme, key: string): Style =
  ## The style for `key`: the theme's, else the registered default.
  if key in theme:
    theme[key]
  else:
    registered.styles.getOrDefault(key)

proc renderSlides*(src: string, width: int, theme = Theme()): seq[Slide] =
  ## The slides of `src` (separated by `---` lines) laid out at `width`
  ## columns, indented by `margin`. Always at least one slide. Every span
  ## is merged over the theme's `slide` style.
  let base = theme.themed("slide")
  for lines in core.renderSlides(src, max(1, width - margin), theme):
    var slide = Slide(style: base)
    for line in lines:
      var row: Line
      if line.len > 0:
        row.add Span(text: ' '.repeat(margin), style: base)
      for span in line:
        row.add Span(text: span.text, style: base.merge(span.style))
      slide.lines.add row
    result.add slide
