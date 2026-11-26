## nimslides: render a markdown file as slides in the terminal.

import std/[parseopt, strutils, terminal, unicode]
import nimslides/[render, viewer]

const NimblePkgVersion {.strdefine.} = "dev"

const usage = """
Usage: nimslides [options] FILE

Show the slides in FILE full screen in the terminal. Slides are
separated by a line of `---` with a blank line above and below.

  right, l, n, space      next slide
  left, h, p, backspace   previous slide
  up/down, j/k            scroll a tall slide one line
  PageUp/PageDown         scroll one page (also mouse wheel)
  q, Escape               quit

Hold shift to select text with the mouse. When stdout is not a
terminal, all slides are printed instead.

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
    # Slides one after another, each after a dashed line with its number,
    # e.g. "┄┄ 2/5 ┄┄┄┄┄┄"; `┄` appears nowhere else in a slide.
    let width = terminalWidth()
    let slides = renderSlides(src, width)
    for i, slide in slides:
      if i > 0:
        let label = "┄┄ " & $(i + 1) & "/" & $slides.len & " "
        let fill = max(0, width - margin - label.runeLen)
        echo "\n", ' '.repeat(margin), label, "┄".repeat(fill), "\n"
      for line in slide.lines:
        echo line.plain

when isMainModule:
  main()
