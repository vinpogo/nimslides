import std/[sequtils, strutils, unittest]
import ../helpers
import nimslides/features/list # only this feature is registered

proc show(blocks: seq[BlockNode]): string

proc show(item: ListItem): string =
  case item.task
  of taskOpen:
    result.add "[ ] "
  of taskDone:
    result.add "[x] "
  of taskNone:
    discard
  result.add item.children.show

proc show(blocks: seq[BlockNode]): string =
  ## A compact form of the block tree: `p"text"`, `ul[...]` or `ol3[...]`
  ## with items separated by " | ", and `*` after the list for a loose one.
  var parts: seq[string]
  for b in blocks:
    if b of Paragraph:
      parts.add "p\"" & Paragraph(b).raw.replace("\n", "\\n") & "\""
    elif b of List:
      let l = List(b)
      var s = (if l.ordered: "ol" & $l.start & l.delimiter else: "ul" & l.bullet)
      if l.loose:
        s.add "*"
      s.add "[" & l.items.mapIt(it.show).join(" | ") & "]"
      parts.add s
    else:
      parts.add "?"
  parts.join(", ")

proc tree(md: string): string =
  parse(md).show

suite "list items: CommonMark examples":
  test "255-258: content indentation decides what belongs to the item":
    check tree("- one\n\n two") == "ul-[p\"one\"], p\"two\""
    check tree("- one\n\n  two") == "ul-*[p\"one\", p\"two\"]"
    check tree(" -    one\n\n     two") == "ul-[p\"one\"], p\"two\""
    check tree(" -    one\n\n      two") == "ul-*[p\"one\", p\"two\"]"

  test "260: a marker needs a space after it":
    check tree("-one\n\n2.two") == "p\"-one\", p\"2.two\""

  test "261: several blank lines inside an item":
    check tree("- foo\n\n\n  bar") == "ul-*[p\"foo\", p\"bar\"]"

  test "264-268: ordered numbers":
    check tree("123456789. ok") == "ol123456789.[p\"ok\"]"
    check tree("1234567890. not ok") == "p\"1234567890. not ok\""
    check tree("0. ok") == "ol0.[p\"ok\"]"
    check tree("003. ok") == "ol3.[p\"ok\"]"
    check tree("-1. not ok") == "p\"-1. not ok\""

  test "270: 5+ spaces after the marker keep the extra indent in the item":
    let blocks = parse("  10.  foo\n\n           bar")
    check blocks.len == 1
    check List(blocks[0]).start == 10
    check List(blocks[0]).items[0].children.len == 2

  test "274-275: content column of 1-4 spaces after the marker":
    check tree("-    foo\n\n  bar") == "ul-[p\"foo\"], p\"bar\""
    check tree("-  foo\n\n   bar") == "ul-*[p\"foo\", p\"bar\"]"

  test "277-278: an item can start with one blank line, not two":
    check tree("-   \n  foo") == "ul-[p\"foo\"]"
    check tree("-\n\n  foo") == "ul-[], p\"foo\""

  test "279-282: empty items":
    check tree("- foo\n-\n- bar") == "ul-[p\"foo\" |  | p\"bar\"]"
    check tree("- foo\n-   \n- bar") == "ul-[p\"foo\" |  | p\"bar\"]"
    check tree("1. foo\n2.\n3. bar") == "ol1.[p\"foo\" |  | p\"bar\"]"
    check tree("*") == "ul*[]"

  test "283: an empty item can't interrupt a paragraph":
    check tree("foo\n*\n\nfoo\n1.") == "p\"foo\\n*\", p\"foo\\n1.\""

  test "289: lazy continuation":
    check tree("  1.  A paragraph\n    with two lines.") ==
      "ol1.[p\"A paragraph\\nwith two lines.\"]"
    check tree("- a\nb\n- c") == "ul-[p\"a\\nb\" | p\"c\"]"

  test "292-293: nesting needs the content column":
    check tree("- foo\n  - bar\n    - baz\n      - boo") ==
      "ul-[p\"foo\", ul-[p\"bar\", ul-[p\"baz\", ul-[p\"boo\"]]]]"
    check tree("- foo\n - bar\n  - baz\n   - boo") ==
      "ul-[p\"foo\" | p\"bar\" | p\"baz\" | p\"boo\"]"

  test "294-295: under an ordered item":
    check tree("10) foo\n    - bar") == "ol10)[p\"foo\", ul-[p\"bar\"]]"
    check tree("10) foo\n   - bar") == "ol10)[p\"foo\"], ul-[p\"bar\"]"

  test "296-297: a list as the first block of an item":
    check tree("- - foo") == "ul-[ul-[p\"foo\"]]"
    check tree("1. - 2. foo") == "ol1.[ul-[ol2.[p\"foo\"]]]"

suite "lists: CommonMark examples":
  test "301-302: another bullet or delimiter starts a new list":
    check tree("- foo\n- bar\n+ baz") == "ul-[p\"foo\" | p\"bar\"], ul+[p\"baz\"]"
    check tree("1. foo\n2. bar\n3) baz") == "ol1.[p\"foo\" | p\"bar\"], ol3)[p\"baz\"]"

  test "303-305: interrupting a paragraph":
    check tree("Foo\n- bar\n- baz") == "p\"Foo\", ul-[p\"bar\" | p\"baz\"]"
    check tree("The number of windows in my house is\n14.  The number of doors is 6.") ==
      "p\"The number of windows in my house is\\n14.  The number of doors is 6.\""
    check tree("The number of windows in my house is\n1.  The number of doors is 6.") ==
      "p\"The number of windows in my house is\", ol1.[p\"The number of doors is 6.\"]"

  test "306-307: blank lines between items make a list loose":
    check tree("- foo\n\n- bar\n\n\n- baz") == "ul-*[p\"foo\" | p\"bar\" | p\"baz\"]"
    check tree("- foo\n  - bar\n    - baz\n\n\n      bim") ==
      "ul-[p\"foo\", ul-[p\"bar\", ul-*[p\"baz\", p\"bim\"]]]"

  test "310-312: sibling items may be indented differently":
    check tree("- a\n - b\n  - c\n   - d\n  - e\n - f\n- g") ==
      "ul-[p\"a\" | p\"b\" | p\"c\" | p\"d\" | p\"e\" | p\"f\" | p\"g\"]"
    check tree("1. a\n\n  2. b\n\n   3. c") == "ol1.*[p\"a\" | p\"b\" | p\"c\"]"
    check tree("- a\n - b\n  - c\n   - d\n    - e") ==
      "ul-[p\"a\" | p\"b\" | p\"c\" | p\"d\\n- e\"]"

  test "313: four spaces of indent is not an item":
    let blocks = parse("1. a\n\n  2. b\n\n    3. c")
    check blocks.len == 2
    check List(blocks[0]).items.len == 2
    check blocks[1] of Paragraph # indented code, when that feature is there

  test "314-316: loose lists":
    check tree("- a\n- b\n\n- c") == "ul-*[p\"a\" | p\"b\" | p\"c\"]"
    check tree("* a\n*\n\n* c") == "ul**[p\"a\" |  | p\"c\"]"
    check tree("- a\n- b\n\n  c\n- d") == "ul-*[p\"a\" | p\"b\", p\"c\" | p\"d\"]"

  test "319: a blank line inside a nested list keeps the outer list tight":
    check tree("- a\n  - b\n\n    c\n- d") ==
      "ul-[p\"a\", ul-*[p\"b\", p\"c\"] | p\"d\"]"

  test "322-323: tight lists":
    check tree("- a") == "ul-[p\"a\"]"
    check tree("- a\n  - b") == "ul-[p\"a\", ul-[p\"b\"]]"

  test "325-326: loose outer, tight inner":
    check tree("* foo\n  * bar\n\n  baz") == "ul**[p\"foo\", ul*[p\"bar\"], p\"baz\"]"
    check tree("- a\n  - b\n  - c\n\n- d\n  - e\n  - f") ==
      "ul-*[p\"a\", ul-[p\"b\" | p\"c\"] | p\"d\", ul-[p\"e\" | p\"f\"]]"

suite "lists: other cases":
  test "a trailing blank line does not make a list loose":
    check tree("- a\n- b\n\nafter") == "ul-[p\"a\" | p\"b\"], p\"after\""

  test "an ordered list interrupts a paragraph only from 1":
    check tree("a\n2. b") == "p\"a\\n2. b\""
    check tree("a\n1. b") == "p\"a\", ol1.[p\"b\"]"

  test "any number continues a list":
    check tree("1. a\n1. b\n5. c") == "ol1.[p\"a\" | p\"b\" | p\"c\"]"

  test "a block rule before lists wins over a new item":
    let saved = snapshot()
    defer:
      restore saved
    registerBlock BlockRule(
      name: "test_break",
      priority: 40,
      interruptsParagraph: true,
      parse: proc(p: BlockParser): BlockNode =
        if p.line == "* * *":
          result = Paragraph(raw: "BREAK")
          p.advance
      ,
    )
    check tree("* Foo\n* * *\n* Bar") == "ul*[p\"Foo\"], p\"BREAK\", ul*[p\"Bar\"]"

suite "task items":
  test "open and done":
    check tree("- [ ] a\n- [x] b\n- [X] c") ==
      "ul-[[ ] p\"a\" | [x] p\"b\" | [x] p\"c\"]"

  test "not a task":
    check tree("- [ ]a") == "ul-[p\"[ ]a\"]"
    check tree("- [y] a") == "ul-[p\"[y] a\"]"
    check tree("- a [ ] b") == "ul-[p\"a [ ] b\"]"
    check tree("- [ ]") == "ul-[p\"[ ]\"]"

  test "glyphs and styles":
    check render("- [ ] open\n- [x] done") == @["☐ open", "✔ done"]
    check styleOf("- [x] done", "✔") == Style(fg: indexed(114))
    check styleOf("- [ ] open", "☐") == Style(fg: indexed(244))
    check styleOf("- [ ] open", "open") == Style()

  test "in an ordered list the box follows the number":
    check render("1. [x] done\n2. [ ] open") == @["1. ✔ done", "2. ☐ open"]

suite "list rendering":
  test "bullets by nesting depth":
    check render("- a\n  - b\n    - c\n      - d\n        - e") ==
      @["• a", "  ◦ b", "    ▪ c", "      ‣ d", "        • e"]

  test "bullet and number styles":
    check styleOf("- a", "•") == Style(fg: indexed(205))
    check styleOf("1. a", "1.") == Style(fg: indexed(205))
    check styleOf("- a", "a") == Style()

  test "numbers are right-aligned":
    check render("9. nine\n10. ten") == @[" 9. nine", "10. ten"]
    check render("8) a\n9) b\n10) c", 10) == @[" 8) a", " 9) b", "10) c"]

  test "hanging indent":
    check render("- one two three four", 10) == @["• one two", "  three", "  four"]
    check render("10. one two three", 10) == @["10. one", "    two", "    three"]

  test "tight and loose":
    check render("- a\n- b") == @["• a", "• b"]
    check render("- a\n\n- b") == @["• a", "", "• b"]
    check render("- a\n\n  b\n- c") == @["• a", "", "  b", "", "• c"]
    check render("- a\n  - b\n- c") == @["• a", "  ◦ b", "• c"]

  test "empty items show only the marker":
    check render("- a\n-\n- b") == @["• a", "•", "• b"]

  test "lists after other blocks":
    check render("para\n\n- a") == @["para", "", "• a"]

  test "rows fit the width":
    for md in [example("list"), "1234567. a b c\n- [x] x\n  - y"]:
      for width in 1 .. 60:
        for line in render(md, width):
          check line.displayWidth <= width

  test "the example renders":
    check render(example("list"), 60).len > 20
