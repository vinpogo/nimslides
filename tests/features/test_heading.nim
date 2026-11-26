import std/[strutils, unittest]
import ../helpers
import nimslides/features/heading # only this feature is registered

proc indexed(i: uint8): Color =
  Color(kind: ckIndexed, index: i)

suite "ATX headings":
  test "each level renders without the hashes":
    check render("# One") == @["One", "━━━"]
    check render("## Two") == @["Two", "───"]
    for (md, text) in [
      ("### Three", "Three"),
      ("#### Four", "Four"),
      ("##### Five", "Five"),
      ("###### Six", "Six"),
    ]:
      check render(md) == @[text] # no rule row below h3-h6
    for level in 1 .. 6:
      let node = parse("#".repeat(level) & " x")[0]
      check node of Heading
      check Heading(node).level == level

  test "seven hashes are not a heading":
    check parse("####### x")[0] of Paragraph

  test "the closing sequence is stripped":
    check render("## Two ##") == @["Two", "───"]
    check render("### Three ##########   ") == @["Three"]
    check render("### Three #") == @["Three"]
    check render("# One#") == @["One#", "━━━━"] # no space before: literal
    check render("### b \\###") == @["b ###"] # escaped: literal

  test "a space is required after the hashes":
    check render("#5 bolt") == @["#5 bolt"]
    check render("#hashtag") == @["#hashtag"]
    check parse("#hashtag")[0] of Paragraph

  test "up to 3 spaces of indent":
    check render("   ### Three") == @["Three"]
    check render("    # not a heading") == @["# not a heading"]
    check parse("    # not a heading")[0] of Paragraph

  test "empty headings":
    for md in ["#", "## ", "### ###"]:
      let node = parse(md)[0]
      check node of Heading
      check Heading(node).raw == ""
    check render("a\n\n#\n\nb") == @["a", "", "b"] # takes no space

  test "headings interrupt a paragraph":
    check render("text\n## Two\nmore") == @["text", "", "Two", "───", "", "more"]

  test "inline content passes through":
    check render("# \\*not emphasis\\*") ==
      @["*not emphasis*", "━━━━━━━━━━━━━━"]
    check Heading(parse("# a  *b*  ")[0]).raw == "a  *b*"

  test "long headings wrap; the rule is as wide as the widest line":
    check render("# A heading that is long", 12) ==
      @["A heading", "that is long", "━━━━━━━━━━━━"]
    check render("## Wide 漢字 text", 10) ==
      @["Wide 漢字", "text", "─────────"]

suite "setext headings":
  test "=== gives level 1, --- level 2":
    check render("Title\n=====") == @["Title", "━━━━━"]
    check render("Sub\n---") == @["Sub", "───"]
    check Heading(parse("Title\n=")[0]).level == 1
    check Heading(parse("Sub\n  -  ")[0]).level == 2

  test "a multi-line paragraph becomes the heading":
    check render("one\n  two\n===") == @["one two", "━━━━━━━"]
    check Heading(parse("one\n  two  \n===")[0]).raw == "one\ntwo"

  test "--- after a blank line is not an underline":
    check render("text\n\n---") == @["text", "", "---"] # no thematic break here
    check parse("text\n\n---")[1] of Paragraph

  test "a setext underline wins over a lone --- under a paragraph":
    check parse("a\n---\nb").len == 2
    check render("a\n---\nb") == @["a", "─", "", "b"]

  test "not an underline":
    check render("a\n    ===") == @["a ==="] # indented 4: continuation
    check render("a\n= =") == @["a = ="]
    check render("===") == @["==="]

suite "heading styles":
  test "style keys resolve to the defaults":
    let ctx = newLayoutCtx(40, newDocCtx())
    check ctx.style("heading.1") == Style(bold: true, fg: indexed(205))
    check ctx.style("heading.2") == Style(bold: true, fg: indexed(81))
    check ctx.style("heading.3") == Style(bold: true, fg: indexed(221))
    check ctx.style("heading.4") == Style(bold: true, fg: indexed(114))
    check ctx.style("heading.5") == Style(bold: true, fg: indexed(147))
    check ctx.style("heading.6") == Style(bold: true, italic: true, fg: indexed(245))
    check ctx.style("heading.1.rule") == Style(fg: indexed(205))
    check ctx.style("heading.2.rule") == Style(fg: indexed(81))

  test "headings and rules use them":
    check styleOf("# One", "One") == Style(bold: true, fg: indexed(205))
    check styleOf("# One", "━") == Style(fg: indexed(205))
    check styleOf("Two\n---", "─") == Style(fg: indexed(81))
    check styleOf("###### Six", "Six") ==
      Style(bold: true, italic: true, fg: indexed(245))

suite "headings example":
  test "the example renders":
    check render(example("heading"), 40).len > 0
