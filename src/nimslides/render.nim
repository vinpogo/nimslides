## Lays out a slide's text for the terminal.
##
## The renderer returns styled text, not escape codes, so that whatever draws
## it can cut lines anywhere and paint popups on top. `viewer.nim` paints it
## on the terminal; `plain` gives the text alone.
##
## No markdown handling yet: the source is shown exactly as written.

import std/[strutils, unicode]

type
  ColorKind* = enum
    ckDefault ## the terminal's own foreground or background color
    ckIndexed ## an entry of the 256-color palette; 0-15 are the basic colors
    ckRgb ## a 24-bit color

  Color* = object ## `Color()` is the terminal default
    case kind*: ColorKind
    of ckDefault:
      discard
    of ckIndexed:
      index*: uint8
    of ckRgb:
      r*, g*, b*: uint8

  Style* = object ## `Style()` is plain text in the terminal's colors
    bold*, italic*, underline*, dim*, strikethrough*: bool
    fg*, bg*: Color

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
