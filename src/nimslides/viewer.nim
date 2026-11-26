## The interactive full-screen viewer: the redraw loop and key handling.

import std/[sequtils, terminal]
import ./[ansi, render, term]

proc present*(src: string) =
  ## Shows `src` full screen until the user presses q or ctrl-c.
  enterFullscreen()
  defer:
    exitFullscreen()
  var size = (0, 0)
  while true:
    let current = (terminalWidth(), terminalHeight())
    if current != size: # first frame, or the terminal was resized
      size = current
      drawFrame(renderSlide(src, size[0]).lines.mapIt(it.toAnsi), size[1])
    # Wake up regularly to notice resizes.
    let key = readByte(timeoutMs = 200)
    if key == 'q'.int or key == 3: # q, ctrl-c
      break
