## Styled text: what layout produces and the viewer paints.
##
## The renderer returns styled text, not escape codes, so that whatever draws
## it can cut lines anywhere and paint popups on top.

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
    lines*: seq[Line] # Interactive regions will go here; see docs/architecture.md.

proc `==`*(a, b: Color): bool =
  if a.kind != b.kind:
    return false
  case a.kind
  of ckDefault:
    true
  of ckIndexed:
    a.index == b.index
  of ckRgb:
    a.r == b.r and a.g == b.g and a.b == b.b

proc merge*(base, over: Style): Style =
  ## `base` with `over` on top: attributes add up, and a color of `over`
  ## replaces the one of `base` unless it is the terminal default.
  result = base
  result.bold = base.bold or over.bold
  result.italic = base.italic or over.italic
  result.underline = base.underline or over.underline
  result.dim = base.dim or over.dim
  result.strikethrough = base.strikethrough or over.strikethrough
  if over.fg.kind != ckDefault:
    result.fg = over.fg
  if over.bg.kind != ckDefault:
    result.bg = over.bg

proc plain*(line: Line): string =
  ## The text of `line` without styles.
  for span in line:
    result.add span.text
