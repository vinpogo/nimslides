import std/[os, sequtils, unittest]
import nimslides/render

proc texts(src: string, width: int): seq[string] =
  let slides = renderSlides(src, width)
  check slides.len == 1
  slides[0].lines.mapIt(it.plain)

suite "renderSlides":
  test "indents by the margin; blank lines stay empty":
    check texts("one\n\ntwo\n", 80) == @["  one", "", "  two"]

  test "word wraps paragraphs to the width minus the margin":
    check texts("aa bb cc\ndd", 7) == @["  aa bb", "  cc dd"]
    check texts("äöü äöü", 6) == @["  äöü", "  äöü"]

  test "never cuts text off":
    check texts("abcdef", 4) == @["  ab", "  cd", "  ef"]

  test "the showcase renders without errors":
    check texts(
      readFile(currentSourcePath().parentDir / ".." / "examples" / "showcase.md"), 60
    ).len > 0
