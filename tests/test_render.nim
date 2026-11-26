import std/[sequtils, unittest]
import nimslides/render

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
