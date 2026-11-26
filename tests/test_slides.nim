import std/[sequtils, strutils, unittest]
import nimslides/render

proc slides(src: string, width = 30): seq[seq[string]] =
  renderSlides(src, width).mapIt(it.lines.mapIt(it.plain.strip(leading = false)))

suite "slide separators":
  test "a file without separators is one slide":
    check slides("one\n\ntwo").len == 1
    check slides("").len == 1

  test "`---` between blank lines starts a new slide":
    check slides("one\n\n---\n\ntwo") == @[@["  one"], @["  two"]]
    check slides("one\n\n-----\n\ntwo").len == 2
    check slides("one\n\n   ---  \n\ntwo").len == 2

  test "separators at the start or end add no empty slide":
    check slides("---\n\none\n\n---\n").len == 1
    check slides("---\n\none\n\n---\n\ntwo\n\n---").len == 2

  test "a frontmatter is not shown":
    check slides("---\ntitle: Nim\n---\n\none\n\n---\n\ntwo") ==
      @[@["  one"], @["  two"]]

  test "two separators in a row make a blank slide":
    check slides("one\n\n---\n\n---\n\ntwo") == @[@["  one"], @[], @["  two"]]

  test "without blank lines around it, `---` keeps its markdown meaning":
    check slides("Title\n---\n\ntext").len == 1 # setext heading
    check slides("one\n\n---\ntwo").len == 1 # thematic break
    check slides("one\n\n- - -\n\ntwo").len == 1
    check slides("one\n\n***\n\ntwo").len == 1
    check slides("one\n\n    ---\n\ntwo").len == 1 # indented code

  test "`---` inside code, quotes and lists is content":
    check slides("```\none\n\n---\n\ntwo\n```").len == 1
    check slides("> one\n>\n> ---\n>\n> two").len == 1
    check slides("- one\n\n  ---\n\n  two").len == 1

  test "link references work across slides":
    check slides("[a][r]\n\n---\n\n[r]: http://x.org")[0] == @["  a (http://x.org)"]
