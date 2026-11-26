import std/[strutils, tables, unittest]
import ../helpers
import nimslides/features/blockquote # only this feature is registered

proc quote(node: BlockNode): BlockQuote =
  check node of BlockQuote
  BlockQuote(node)

proc raw(node: BlockNode): string =
  check node of Paragraph
  Paragraph(node).raw

proc isQuote(md: string): bool =
  let blocks = parse(md)
  blocks.len == 1 and blocks[0] of BlockQuote

suite "blockquote: CommonMark examples":
  test "233, 247: lazy continuation":
    let q = parse("> bar\nbaz\n> foo")[0].quote
    check q.children.len == 1
    check q.children[0].raw == "bar\nbaz\nfoo"
    check parse("> bar\nbaz")[0].quote.children[0].raw == "bar\nbaz"

  test "238: an indented lazy line is paragraph text":
    check parse("> foo\n    - bar")[0].quote.children[0].raw == "foo\n- bar"

  test "239-241: empty quotes and empty quote lines":
    check parse(">")[0].quote.children.len == 0
    check parse(">\n>  \n> ")[0].quote.children.len == 0
    let q = parse(">\n> foo\n>  ")[0].quote
    check q.children.len == 1
    check q.children[0].raw == "foo"

  test "242: a blank line separates two quotes":
    let blocks = parse("> foo\n\n> bar")
    check blocks.len == 2
    check blocks[0].quote.children[0].raw == "foo"
    check blocks[1].quote.children[0].raw == "bar"

  test "243-244: one paragraph, or two with an empty quote line":
    check parse("> foo\n> bar")[0].quote.children[0].raw == "foo\nbar"
    let q = parse("> foo\n>\n> bar")[0].quote
    check q.children.len == 2
    check q.children[1].raw == "bar"

  test "245: a quote interrupts a paragraph":
    let blocks = parse("foo\n> bar")
    check blocks.len == 2
    check blocks[0].raw == "foo"
    check blocks[1].quote.children[0].raw == "bar"

  test "248-249: a lazy line needs an open paragraph":
    for md in ["> bar\n\nbaz", "> bar\n>\nbaz"]:
      let blocks = parse(md)
      check blocks.len == 2
      check blocks[0].quote.children[0].raw == "bar"
      check blocks[1].raw == "baz"

  test "250: lazy continuation through nested quotes":
    let q3 = parse("> > > foo\nbar")[0].quote.children[0].quote.children[0].quote
    check q3.children[0].raw == "foo\nbar"

  test "251: markers without spaces, nesting by count":
    let q2 = parse(">>> foo\n> bar\n>>baz")[0].quote.children[0].quote
    check q2.children[0].quote.children[0].raw == "foo\nbar\nbaz"

suite "blockquote: markers":
  test "up to three spaces of indent, not four":
    check isQuote("   > a")
    check not isQuote("    > a")
    check parse("> foo\n    > bar")[0].quote.children[0].raw == "foo\n> bar"

  test "one space after the marker is removed, more are kept":
    check parse(">  foo")[0].quote.children[0].raw == "foo" # paragraph strips
    check parse(">foo")[0].quote.children[0].raw == "foo"

  test "a tab after the marker counts as columns":
    # `>` + tab expands to `>   `; one space belongs to the marker.
    check parse(">\tfoo")[0].quote.children[0].raw == "foo"

suite "blockquote: lazy lines and setext underlines":
  setup:
    let saved = snapshot()
    # A stand-in for the heading feature's setext closer.
    registerParagraphCloser ParagraphCloser(
      name: "test.setext",
      priority: 10,
      close: proc(p: BlockParser): ParagraphBuild =
        if p.line.strip == "===":
          p.advance
          result = proc(lines: seq[string]): BlockNode =
            BlockQuote() # any non-paragraph block
      ,
    )

  teardown:
    restore saved

  test "a lazy === stays paragraph text":
    let q = parse("> foo\n===")[0].quote
    check q.children.len == 1
    check q.children[0].raw == "foo\n\\==="
    check render("> foo\n===") == @["▎ foo ==="]

  test "a quoted === still closes the paragraph":
    check not (parse("> foo\n> ===")[0].quote.children[0] of Paragraph)

suite "blockquote: layout":
  test "a bar in front of every row, also wrapped ones":
    check render("> one two three four", 12) == @["▎ one two", "▎ three four"]

  test "empty rows get the bar without a trailing space":
    check render("> a\n>\n> b") == @["▎ a", "▎", "▎ b"]

  test "an empty quote shows a bar":
    check render(">") == @["▎"]

  test "nested quotes stack their bars":
    check render("> a\n>\n> > b") == @["▎ a", "▎", "▎ ▎ b"]

  test "separate quotes have an unbarred gap":
    check render("> a\n\n> b") == @["▎ a", "", "▎ b"]

  test "rows never exceed the width":
    let md = example("blockquote")
    for width in 1 .. 50:
      for row in styled(md, width):
        check row.plain.displayWidth <= width

  test "very narrow widths drop the space, then the bar":
    check render("> ab", 2) == @["▎a", "▎b"]
    check render("> ab", 1) == @["a", "b"]

suite "blockquote: styles":
  test "bar and content styles":
    check styleOf("> hi", "▎") == Style(fg: Color(kind: ckIndexed, index: 99))
    check styleOf("> hi", "hi") ==
      Style(italic: true, fg: Color(kind: ckIndexed, index: 250))

  test "the quote style goes under the children's own styles":
    var ctx = newLayoutCtx(40, newDocCtx())
    ctx.theme["blockquote"] = Style(italic: true, fg: Color(kind: ckIndexed, index: 1))
    ctx.theme["paragraph"] = Style(bold: true, fg: Color(kind: ckIndexed, index: 2))
    let rows = ctx.layoutBlocks(parse("> hi"))
    check rows[0][1].text == "hi"
    # attributes add up, the child's color wins
    check rows[0][1].style ==
      Style(bold: true, italic: true, fg: Color(kind: ckIndexed, index: 2))

  test "a theme can restyle the bar":
    let red = Style(fg: Color(kind: ckIndexed, index: 1))
    var ctx = newLayoutCtx(40, newDocCtx())
    ctx.theme["blockquote.bar"] = red
    check ctx.layoutBlocks(parse("> hi"))[0][0].style == red

suite "blockquote: example":
  test "the example renders":
    let rows = render(example("blockquote"), 60)
    check rows.len > 0
    for row in rows:
      check row == "" or row.startsWith("▎") or row == "A paragraph can be interrupted"
