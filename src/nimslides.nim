## nimslides: render a markdown file as slides in the terminal.

import std/[parseopt, terminal]
import nimslides/[render, viewer]

const NimblePkgVersion {.strdefine.} = "dev"

const usage = """
Usage: nimslides [options] FILE

Show FILE full screen in the terminal. Press q to quit.
A slide taller than the window scrolls with the arrow keys or
j/k (one line), PageUp/PageDown (one page), and the mouse wheel
or touchpad. Hold shift to select text with the mouse.
When stdout is not a terminal, the slide is printed instead.

Options:
  -h, --help          show this help
  -v, --version       show the version"""

proc main() =
  var path = ""
  for kind, key, val in getopt():
    case kind
    of cmdArgument:
      if path.len > 0:
        quit "nimslides: expected a single FILE\n\n" & usage, 2
      path = key
    of cmdLongOption, cmdShortOption:
      case key
      of "h", "help":
        echo usage
        quit 0
      of "v", "version":
        echo NimblePkgVersion
        quit 0
      else:
        quit "nimslides: unknown option '" & key & "'\n\n" & usage, 2
    of cmdEnd:
      discard
  if path.len == 0:
    quit usage, 2

  let src =
    try:
      readFile(path)
    except IOError as e:
      quit "nimslides: cannot read " & path & ": " & e.msg, 1

  if isatty(stdout) and isatty(stdin):
    present(src)
  else:
    for line in renderSlide(src, terminalWidth()).lines:
      echo line.plain

when isMainModule:
  main()
