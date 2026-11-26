## Lays out a slide's text for the terminal.
##
## The renderer returns styled text, not escape codes, so that whatever draws
## it can cut lines anywhere and paint popups on top. `ansi.nim` turns it
## into terminal output.
##
## No markdown handling yet: the source is shown exactly as written.

import std/[strutils, unicode]

type
  Style* = object
    bold*, italic*, underline*, dim*: bool
    fg* = -1 ## 256-color palette index, -1 = terminal default
    bg* = -1

  Span* = object ## a piece of text in one style
    text*: string
    style*: Style

  Line* = seq[Span]

  Slide* = object
    lines*: seq[Line]
    # Interactive regions (e.g. an expandable code block, with the rows it
    # covers) will go here once something on a slide is interactive.

const margin* = 2 ## columns of space left of the slide

proc plain*(line: Line): string =
  ## The text of `line` without styles.
  for span in line:
    result.add span.text

proc renderSlide*(src: string, width: int): Slide =
  ## One output line per source line, indented by `margin` and cut off at
  ## `width` columns.
  let room = max(0, width - margin)
  for text in src.strip(leading = false, chars = {'\n'}).splitLines:
    let text = text.replace("\t", "    ")
    if text.len == 0:
      result.lines.add @[]
    else:
      result.lines.add @[
        Span(text: ' '.repeat(margin)), Span(text: text.runeSubStr(0, room))
      ]
