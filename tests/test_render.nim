import std/[sequtils, unittest]
import nimslides/[ansi, render]

proc texts(src: string, width: int): seq[string] =
  renderSlide(src, width).lines.mapIt(it.plain)

suite "renderSlide":
  test "shows the source as written, indented by the margin":
    check texts("# Title\n\n*text*\n", 80) == @["  # Title", "", "  *text*"]

  test "cuts off lines wider than the terminal":
    check texts("abcdef", 6) == @["  abcd"]
    check texts("äöüß", 4) == @["  äö"]

  test "expands tabs":
    check texts("\tx", 80) == @["      x"]

suite "toAnsi":
  let line = @[Span(text: "a"), Span(text: "b", style: Style(bold: true, fg: 205))]

  test "wraps styled spans in escape codes":
    check line.toAnsi == "a\e[1;38;5;205mb\e[0m"

  test "leaves the codes out without color":
    check line.toAnsi(color = false) == "ab"
