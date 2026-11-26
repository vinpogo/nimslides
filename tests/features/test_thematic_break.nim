import std/[sequtils, strutils, unittest]
import ../helpers
import nimslides/features/thematic_break # only this feature is registered

proc rule(width = 40): string =
  "─".repeat(width)

proc isBreak(md: string): bool =
  let blocks = parse(md)
  blocks.len == 1 and blocks[0] of ThematicBreak

suite "thematic break: CommonMark examples":
  test "43: the three characters":
    check parse("***\n---\n___").len == 3
    for b in parse("***\n---\n___"):
      check b of ThematicBreak

  test "44-46: wrong characters, too few":
    check not isBreak("+++")
    check not isBreak("===")
    check not isBreak("--\n**\n__")
    check parse("--\n**\n__")[0] of Paragraph

  test "47: up to three spaces of indent":
    check isBreak(" ***")
    check isBreak("  ***")
    check isBreak("   ***")

  test "48-49: four spaces is too much":
    check not isBreak("    ***")
    # 49: continues a paragraph instead
    check parse("Foo\n    ***").len == 1
    check parse("Foo\n    ***")[0] of Paragraph

  test "50: more than three characters":
    check isBreak("_____________________________________")

  test "51-53: spaces between the characters":
    check isBreak(" - - -")
    check isBreak(" **  * ** * ** * **")
    check isBreak("-     -      -      -")

  test "54: spaces at the end":
    check isBreak("- - - -    ")

  test "55-56: no other characters":
    for md in ["_ _ _ _ a", "a------", "---a---", " *-*"]:
      check not isBreak(md)

  test "57: tabs count as spaces":
    check isBreak("-\t-\t-")
    check isBreak("*\t*  \t*")

  test "59: interrupts a paragraph":
    let blocks = parse("Foo\n***\nbar")
    check blocks.len == 3
    check blocks[0] of Paragraph
    check blocks[1] of ThematicBreak
    check blocks[2] of Paragraph

suite "thematic break: layout":
  test "one row exactly as wide as the content":
    for w in [1, 5, 20, 40, 79, 120]:
      check render("***", w) == @[rule(w)]

  test "between paragraphs":
    check render("Foo\n***\nbar", 10) == @["Foo", "", rule(10), "", "bar"]

  test "style":
    check styleOf("---", "─") == Style(fg: Color(kind: ckIndexed, index: 240))

  test "the example renders":
    let lines = render(example("thematic_break"), 40)
    check lines.len > 0
    check lines.count(rule()) == 7
