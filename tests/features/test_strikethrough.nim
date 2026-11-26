## GFM strikethrough, checked against the GFM spec (0.29-gfm,
## "Strikethrough (extension)"; example numbers in comments).

import std/[tables, unittest]
import ../helpers
import nimslides/features/strikethrough

proc dump(nodes: seq[InlineNode]): string =
  ## The node structure, e.g. "a del(b)".
  for node in nodes:
    if node of Text:
      result.add Text(node).text
    elif node of Strikethrough:
      result.add "del(" & Strikethrough(node).children.dump & ")"
    else:
      raiseAssert "unexpected node"

proc inl(raw: string): string =
  parseInline(raw).dump

const struck = Style(strikethrough: true)

suite "strikethrough: structure":
  test "spec examples":
    check inl("~~Hi~~ Hello, ~there~ world!") == "del(Hi) Hello, del(there) world!" # 491
    check render("This ~~has a\n\nnew paragraph~~.") ==
      @["This ~~has a", "", "new paragraph~~."] # 492
    check inl("This will ~~~not~~~ strike.") == "This will ~~~not~~~ strike." # 493

  test "opener and closer must have the same length":
    check inl("~~a~") == "~~a~"
    check inl("~a~~") == "~a~~"
    check inl("~~a~ b~~") == "del(a~ b)"
    check inl("~a~~b~") == "del(a~~b)"

  test "unmatched runs stay literal":
    check inl("~~open") == "~~open"
    check inl("close~~") == "close~~"
    check inl("a ~~ b ~~ c") == "a ~~ b ~~ c" # not flanking
    check inl("~~~~a~~~~") == "~~~~a~~~~"

  test "intraword and across soft breaks":
    check inl("un~~believ~~able") == "undel(believ)able"
    check inl("~~one\ntwo~~") == "del(one two)"

  test "nesting":
    check inl("~~a ~b~ c~~") == "del(a del(b) c)"
    check inl("x ~~a~~ y ~b~ z") == "x del(a) y del(b) z"

  test "escapes stay literal":
    check inl("\\~~a~~") == "~~a~~" # escaped ~, then runs of 1 and 2 do not pair
    check inl("\\~\\~a\\~\\~") == "~~a~~"

suite "strikethrough: rendering":
  test "plain text drops the delimiters":
    check render("~~Hi~~ Hello, ~there~ world!") == @["Hi Hello, there world!"]
    check render("~~~not~~~") == @["~~~not~~~"]

  test "struck text gets the strikethrough attribute":
    check runs("x ~~a~~ y") == @[("x ", Style()), ("a", struck), (" y", Style())]
    check runs("~b~") == @[("b", struck)]

  test "styles merge with the surrounding base style":
    let red = Style(fg: indexed(1))
    check runs("a ~~b~~", {"paragraph": red}.toTable) ==
      @[("a ", red), ("b", Style(strikethrough: true, fg: red.fg))]

  test "theme overrides the style key":
    let dimmed = Style(dim: true)
    check runs("~~a~~", {"strikethrough": dimmed}.toTable) == @[("a", dimmed)]

  test "strikethrough wraps across lines":
    check render("~~one two three~~", 8) == @["one two", "three"]
    check styleOf("~~one two three~~", "three", 8) == struck

  test "the example renders":
    check render(example("strikethrough"), 60).len > 0
