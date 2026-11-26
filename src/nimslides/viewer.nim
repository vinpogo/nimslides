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

proc maxTop*(lines, height: int): int =
  ## The largest useful scroll offset: the last line sits on the bottom row.
  max(0, lines - height)

const WheelLines* = 3 ## lines per mouse-wheel or touchpad scroll event

proc scrollDelta*(event: Event, height: int): int =
  ## How many lines `event` scrolls a window of `height` rows: negative is
  ## up, 0 means it doesn't scroll. Paging keeps one line of context.
  let page = max(1, height - 1)
  case event.kind
  of Key:
    case event.key.code
    of ArrowDown:
      1
    of ArrowUp:
      -1
    of PageDown:
      page
    of PageUp:
      -page
    of Char:
      case event.key.char
      of "j": 1
      of "k": -1
      else: 0
    else:
      0
  of Mouse:
    # Touchpads send the same wheel events as a mouse wheel, just more of
    # them; clicks and motion don't scroll.
    if event.mouse.kind != Press:
      0
    elif event.mouse.button == WheelDown:
      WheelLines
    elif event.mouse.button == WheelUp:
      -WheelLines
    else:
      0
  else:
    0

proc scrolled*(top, delta, lines, height: int): int =
  ## `top` moved by `delta` lines, kept between the first line and the
  ## point where the last line sits on the bottom row.
  clamp(top + delta, 0, maxTop(lines, height))

proc paint(buf: var Buffer, slide: Slide, top: int) =
  ## Writes `slide` into `buf`, starting at line `top`; celina crops what
  ## doesn't fit.
  for y in 0 ..< buf.area.height:
    if top + y >= slide.lines.len:
      break
    let line = slide.lines[top + y]
    var x = 0
    for span in line:
      buf.setString(x, y, span.text, span.style.toCelina)
      x += span.text.displayWidth

var hookTerm: Terminal ## the terminal the SIGINT hook restores

proc present*(src: string) =
  ## Shows `src` full screen until the user presses q, Escape or ctrl-c.
  ## Slides taller than the window scroll with the arrow keys and j/k (one
  ## line), PageUp/PageDown (one page), and the mouse wheel or touchpad.
  let term = newTerminal()
  # Alternate screen and raw mode. Raw mode turns off ISIG, so ctrl-c arrives
  # as a `Quit` event rather than SIGINT, and the `finally` below restores
  # the terminal on every way out, exceptions included.
  term.setup()
  # Mouse reporting, for the wheel and touchpad. Terminals then leave text
  # selection to shift+drag. `cleanup` and `emergencyRestore` turn it off.
  term.enableMouse()
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
    var
      shown: Size # what is on screen; zero before the first frame
      slide: Slide # laid out for `shown.width`
      top = 0 # index of the slide line on the top row
      dirty = true
    while true:
      term.updateSize()
      if term.size != shown:
        # First frame, or the terminal was resized: lay the slide out again
        # and keep the offset valid for the new height. celina redraws the
        # whole screen by itself when the buffer size changes.
        if term.size.width != shown.width:
          slide = renderSlide(src, term.size.width)
        shown = term.size
        top = min(top, maxTop(slide.lines.len, shown.height))
        dirty = true
      if dirty:
        var buf = newBuffer(shown.width, shown.height)
        buf.paint(slide, top)
        term.draw(buf) # sends only the cells that changed
        dirty = false
      # celina has no resize signal, so wake up regularly to check the size.
      # Nothing is drawn while it stays the same.
      if pollEvents(200):
        # Handle everything already waiting before drawing again, so a fast
        # touchpad swipe costs one frame, not one per event.
        var quitting = false
        while hasInput():
          let event = pollKey()
          case event.kind
          of Quit, InputClosed:
            quitting = true
          of Key:
            if event.key.code == Escape or
                (event.key.code == Char and event.key.char in ["q", "Q"]):
              quitting = true
          else:
            discard
          if quitting:
            break
          let next =
            top.scrolled(event.scrollDelta(shown.height), slide.lines.len, shown.height)
          if next != top:
            top = next
            dirty = true
        if quitting:
          break
  finally:
    term.cleanup() # also shows the cursor again
