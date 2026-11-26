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

proc slideDelta*(event: Event): int =
  ## Which way `event` moves through the deck: 1 next, -1 previous, 0 not.
  if event.kind != Key:
    return 0
  case event.key.code
  of ArrowRight, Space:
    1
  of ArrowLeft, Backspace:
    -1
  of Char:
    case event.key.char
    of "l", "n", " ": 1
    of "h", "p": -1
    else: 0
  else:
    0

proc counter*(current, total: int): string =
  ## The slide number shown in the bottom right, e.g. "3/7"; empty for a
  ## single slide.
  if total > 1:
    $(current + 1) & "/" & $total
  else:
    ""

proc scrolled*(top, delta, lines, height: int): int =
  ## `top` moved by `delta` lines, kept between the first line and the
  ## point where the last line sits on the bottom row.
  clamp(top + delta, 0, maxTop(lines, height))

proc paint*(buf: var Buffer, slide: Slide, top, rows: int) =
  ## Fills `buf` with the slide's background, then writes `slide` into the
  ## first `rows` rows, starting at line `top`; celina crops what doesn't
  ## fit.
  buf.clear(cell(" ", slide.style.toCelina))
  for y in 0 ..< min(rows, buf.area.height):
    if top + y >= slide.lines.len:
      break
    let line = slide.lines[top + y]
    var x = 0
    for span in line:
      buf.setString(x, y, span.text, span.style.toCelina)
      x += span.text.displayWidth

type Footer* = object ## the texts on the bottom row
  author*: string ## left
  title*: string ## centered
  counter*: string ## right, e.g. "3/7"

proc isEmpty*(footer: Footer): bool =
  footer.author.len == 0 and footer.title.len == 0 and footer.counter.len == 0

proc paintFooter*(
    buf: var Buffer,
    footer: Footer,
    row, authorStyle, titleStyle, counterStyle: render.Style,
) =
  ## Fills the bottom row of `buf` in `row` and writes the author at its
  ## left, the title centered and the counter at its right, one column in
  ## from the edges. When they don't fit, the counter wins, then the author
  ## (cropped), and the title is left out unless it fits centered with a
  ## space on both sides. Nothing for an empty `footer`.
  if footer.isEmpty or buf.area.height == 0:
    return
  let
    y = buf.area.height - 1
    width = buf.area.width
  buf.fill(rect(0, y, width, 1), cell(" ", row.toCelina))
  # `free` is the first column of the counter, or the row's end without one
  var free = width
  if footer.counter.len > 0:
    free = max(0, width - footer.counter.displayWidth - 1)
    buf.setString(free, y, footer.counter, counterStyle.toCelina)
  var authorEnd = 0 # first column after the author
  if footer.author.len > 0:
    let author = footer.author.truncateToWidth(free - 2) # a space before the counter
    buf.setString(1, y, author, authorStyle.toCelina)
    if author.len > 0:
      authorEnd = 1 + author.displayWidth
  if footer.title.len > 0:
    let w = footer.title.displayWidth
    let x = (width - w) div 2
    let left =
      if authorEnd > 0:
        authorEnd + 1
      else:
        0
    let right =
      if free < width:
        free - 1
      else:
        width
    if x >= left and x + w <= right:
      buf.setString(x, y, footer.title, titleStyle.toCelina)

var hookTerm: Terminal ## the terminal the SIGINT hook restores

proc present*(src: string, theme = Theme()) =
  ## Shows the slides of `src` full screen until the user presses q, Escape
  ## or ctrl-c. Right/left, l/h, n/p, space/backspace change slides. Slides
  ## taller than the window scroll with the arrow keys and j/k (one line),
  ## PageUp/PageDown (one page), and the mouse wheel or touchpad. The bottom
  ## row shows the frontmatter's author and title and, with more than one
  ## slide, the slide number. `theme` overrides default styles.
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
  let meta = src.splitFrontmatter.meta
  try:
    hideCursor()
    var
      shown: Size # what is on screen; zero before the first frame
      slides: seq[Slide] # laid out for `shown.width`; never empty
      current = 0 # index of the slide on screen
      top = 0 # index of the slide line on the top row
      dirty = true
    template footer(): Footer =
      Footer(
        author: meta.author, title: meta.title, counter: counter(current, slides.len)
      )

    template rows(): int =
      # rows for the slide; the bottom row is the footer if there is one
      if not footer.isEmpty:
        max(1, shown.height - 1)
      else:
        shown.height

    while true:
      term.updateSize()
      if term.size != shown:
        # First frame, or the terminal was resized: lay the slide out again
        # and keep the offset valid for the new height. celina redraws the
        # whole screen by itself when the buffer size changes.
        if term.size.width != shown.width:
          slides = renderSlides(src, term.size.width, theme)
        shown = term.size
        top = min(top, maxTop(slides[current].lines.len, rows))
        dirty = true
      if dirty:
        var buf = newBuffer(shown.width, shown.height)
        buf.paint(slides[current], top, rows)
        let row = slides[current].style.merge(theme.themed("footer"))
        buf.paintFooter(
          footer,
          row,
          row.merge(theme.themed("footer.author")),
          row.merge(theme.themed("footer.title")),
          row.merge(theme.themed("footer.counter")),
        )
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
          let slide = clamp(current + event.slideDelta, 0, slides.high)
          if slide != current:
            current = slide
            top = 0 # each slide starts at its top
            dirty = true
            continue
          let next =
            top.scrolled(event.scrollDelta(rows), slides[current].lines.len, rows)
          if next != top:
            top = next
            dirty = true
        if quitting:
          break
  finally:
    term.cleanup() # also shows the cursor again
