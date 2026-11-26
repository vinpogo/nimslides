## Full-screen terminal output and raw key input (POSIX only).

import std/[posix, termios]

var saved: Termios
var active = false

proc enterFullscreen*() =
  ## Switches to the alternate screen with raw, unechoed input.
  if active:
    return
  discard tcGetAttr(STDIN_FILENO, addr saved)
  var raw = saved
  raw.c_iflag = raw.c_iflag and not Cflag(BRKINT or ICRNL or INPCK or ISTRIP or IXON)
  raw.c_lflag = raw.c_lflag and not Cflag(ECHO or ICANON or IEXTEN or ISIG)
  raw.c_cc[VMIN] = 1.char
  raw.c_cc[VTIME] = 0.char
  discard tcSetAttr(STDIN_FILENO, TCSAFLUSH, addr raw)
  stdout.write "\e[?1049h\e[?25l"
  stdout.flushFile
  active = true

proc exitFullscreen*() =
  ## Restores the normal screen and terminal settings.
  if not active:
    return
  stdout.write "\e[?25h\e[?1049l"
  stdout.flushFile
  discard tcSetAttr(STDIN_FILENO, TCSAFLUSH, addr saved)
  active = false

proc readByte*(timeoutMs: cint): int =
  ## Next input byte, or -1 if none arrives within `timeoutMs`.
  var fds = [TPollfd(fd: STDIN_FILENO, events: POLLIN)]
  if poll(addr fds[0], 1, timeoutMs) <= 0:
    return -1
  var c: char
  if read(STDIN_FILENO, addr c, 1) != 1:
    return -1
  c.int

proc drawFrame*(lines: openArray[string], height: int) =
  ## Clears the screen and writes up to `height` of `lines` from the top.
  var frame = "\e[H\e[2J"
  for i in 0 ..< min(lines.len, height):
    if i > 0:
      frame.add "\r\n"
    frame.add lines[i]
  stdout.write frame
  stdout.flushFile
