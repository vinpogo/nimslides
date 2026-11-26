import std/unittest
import ../helpers
import nimslides/features/hard_break # only this feature is registered

proc dump(nodes: seq[InlineNode]): string =
  ## e.g. "foo<br>baz"
  for node in nodes:
    if node of HardBreak:
      result.add "<br>"
    elif node of Text:
      result.add Text(node).text

suite "hard line breaks (CommonMark 633-637, 644-645)":
  test "two or more spaces before a line ending":
    check parseInline("foo  \nbaz").dump == "foo<br>baz" # 633
    check parseInline("foo       \nbaz").dump == "foo<br>baz" # 635
    check render("foo  \nbaz") == @["foo", "baz"]

  test "a backslash before a line ending":
    check parseInline("foo\\\nbaz").dump == "foo<br>baz" # 634
    check render("foo\\\nbaz") == @["foo", "baz"]

  test "leading spaces of the next line are ignored":
    check parseInline("foo  \n     bar").dump == "foo<br>bar" # 636
    check parseInline("foo\\\n     bar").dump == "foo<br>bar" # 637
    check render("foo  \n     bar") == @["foo", "bar"]

  test "at the end of a paragraph it does nothing":
    check render("foo\\") == @["foo\\"] # 644
    check render("foo  ") == @["foo"] # 645
    check parse("foo  ")[0] of Paragraph

suite "not a hard break":
  test "one space before a line ending is a soft break":
    check parseInline("foo \nbaz").dump == "foo baz"
    check render("foo \nbaz") == @["foo baz"]

  test "spaces inside a line stay text":
    check parseInline("a  b   c").dump == "a  b   c"
    check render("a  b") == @["a  b"]
    check parseInline("a  b").len == 1 # merged into one Text node

  test "a backslash before anything else is core's":
    check parseInline("\\*a\\b").dump == "*a\\b"
    check parseInline("a\\ \nb").dump == "a\\ b"

suite "layout":
  test "consecutive breaks give an empty line":
    check render("a\\\n\\\nb") == @["a", "", "b"]

  test "lines wrap on both sides of a break":
    check render("one two three  \nfour five six", 9) ==
      @["one two", "three", "four five", "six"]

  test "the break keeps the surrounding style":
    let lines = styled("foo  \nbar")
    check lines.len == 2
    check lines[0][0].text == "foo"
    check lines[1][0].text == "bar"

  test "rows stay within the width":
    let md = example("hard_break")
    for width in 10 .. 60:
      for line in styled(md, width):
        check line.plain.len <= width

  test "the example renders":
    check render(example("hard_break"), 40).len > 0
