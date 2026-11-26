## The interactive full-screen viewer: the redraw loop and key handling.
##
## This is the only module that talks to the terminal, through celina's
## low-level API: a `Terminal` that owns the screen modes and a `Buffer` we
## paint and hand to `draw`, which sends only what changed.

import pkg/celina/core/[buffer, colors, events, geometry, terminal]
import ./render

proc toCelina*(color: render.Color): ColorValue =
  ## celina's color for `color`.
  case color.kind
  of ckDefault:
    ColorValue(kind: Default)
  of ckIndexed:
    ColorValue(kind: Indexed256, indexed256: color.index)
  of ckRgb:
    ColorValue(kind: Rgb, rgb: RgbColor(r: color.r, g: color.g, b: color.b))

proc toCelina*(style: render.Style): colors.Style =
  ## celina's style for `style`.
  result = colors.Style(fg: style.fg.toCelina, bg: style.bg.toCelina)
  if style.bold:
    result.modifiers.incl Bold
  if style.dim:
    result.modifiers.incl Dim
  if style.italic:
    result.modifiers.incl Italic
  if style.underline:
    result.modifiers.incl Underline
  if style.strikethrough:
    result.modifiers.incl Crossed

proc paint(buf: var Buffer, slide: Slide) =
  ## Writes `slide` into `buf` from the top left; celina crops what doesn't fit.
  for y, line in slide.lines:
    if y >= buf.area.height:
      break
    var x = 0
    for span in line:
      buf.setString(x, y, span.text, span.style.toCelina)
      x += span.text.displayWidth

var hookTerm: Terminal ## the terminal the SIGINT hook restores

proc present*(src: string) =
  ## Shows `src` full screen until the user presses q, Escape or ctrl-c.
  let term = newTerminal()
  # Alternate screen and raw mode. Raw mode turns off ISIG, so ctrl-c arrives
  # as a `Quit` event rather than SIGINT, and the `finally` below restores
  # the terminal on every way out, exceptions included.
  term.setup()
  # A SIGINT from elsewhere (`kill -INT`) skips the `finally`.
  hookTerm = term
  setControlCHook(
    proc() {.noconv.} =
      {.cast(gcsafe).}:
        hookTerm.emergencyRestore()
      quit 1 # Nim turns codes above 127 into 127
  )
  try:
    hideCursor()
    var shown: Size # what is on screen; zero before the first frame
    while true:
      term.updateSize()
      if term.size != shown:
        # First frame, or the terminal was resized; celina redraws the whole
        # screen by itself when the buffer size changes.
        shown = term.size
        var buf = newBuffer(shown.width, shown.height)
        buf.paint(renderSlide(src, shown.width))
        term.draw(buf)
      # celina has no resize signal, so wake up regularly to check the size.
      # Nothing is drawn while it stays the same.
      if pollEvents(200):
        let event = pollKey()
        case event.kind
        of Quit, InputClosed:
          break
        of Key:
          if event.key.code == Escape or
              (event.key.code == Char and event.key.char in ["q", "Q"]):
            break
        else:
          discard
  finally:
    term.cleanup() # also shows the cursor again
