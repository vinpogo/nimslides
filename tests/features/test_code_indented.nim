import std/[strutils, tables, unittest]
import ../helpers
import nimslides/features/code_indented # only this feature is registered

const shade = Style(fg: indexed(252), bg: indexed(235))

proc blank(width = 20): string =
  ' '.repeat(width)

proc row(text: string, width = 20): string =
  ## A content row: 2 columns of padding, then `text`, shaded to `width`.
  "  " & text & ' '.repeat(width - 2 - text.displayWidth)

proc code(md: string): IndentedCode =
  let blocks = parse(md)
  check blocks.len == 1
  check blocks[0] of IndentedCode
  IndentedCode(blocks[0])

suite "indented code":
  test "4 spaces start a block and are removed (spec 107)":
    check code("    a simple\n      indented code block").lines ==
      @["a simple", "  indented code block"]
    check render("    a simple\n      indented code block", 30) ==
      @[blank(30), row("a simple", 30), row("  indented code block", 30), blank(30)]

  test "3 spaces are not enough":
    check parse("   foo")[0] of Paragraph

  test "the content is literal (spec 110)":
    let md = "    <a/>\n    *hi*\n\n    - one"
    check code(md).lines == @["<a/>", "*hi*", "", "- one"]
    check render(md, 20) ==
      @[blank(), row("<a/>"), row("*hi*"), blank(), row("- one"), blank()]

  test "blank lines inside are kept (spec 111)":
    check code("    chunk1\n\n    chunk2\n  \n \n \n    chunk3").lines ==
      @["chunk1", "", "chunk2", "", "", "", "chunk3"]

  test "blank lines keep spaces beyond the first 4 (spec 112)":
    check code("    chunk1\n      \n      chunk2").lines == @[
      "chunk1", "  ", "  chunk2"
    ]

  test "it cannot interrupt a paragraph (spec 113)":
    let blocks = parse("Foo\n    bar")
    check blocks.len == 1
    check blocks[0] of Paragraph
    check render("Foo\n    bar") == @["Foo bar"]

  test "a paragraph interrupts it without a blank line (spec 114)":
    let blocks = parse("    foo\nbar")
    check blocks.len == 2
    check blocks[0] of IndentedCode
    check IndentedCode(blocks[0]).lines == @["foo"]
    check blocks[1] of Paragraph
    check render("    foo\nbar", 20) == @[blank(), row("foo"), blank(), "", "bar"]

  test "only the first 4 spaces are removed (spec 116)":
    check code("        foo\n    bar").lines == @["    foo", "bar"]

  test "leading and trailing blank lines are dropped (spec 117)":
    check code("\n    \n    foo\n    \n\n").lines == @["foo"]
    check code("    foo\n\n      \n").lines == @["foo"]

  test "trailing blank lines stay outside the block":
    let blocks = parse("    a\n\n\nnext")
    check blocks.len == 2
    check IndentedCode(blocks[0]).lines == @["a"]
    check render("    a\n\n\nnext", 20) == @[blank(), row("a"), blank(), "", "next"]

  test "trailing spaces are kept (spec 118)":
    check code("    foo  ").lines == @["foo  "]

  test "tabs are expanded like everywhere else":
    check code("\tfoo\tbar").lines == @["foo bar"]

  test "long lines are hard-wrapped, keeping whitespace":
    check render("    0123456789  abcdefghij", 12) ==
      @[
        blank(12),
        row("0123456789", 12),
        row("  abcdefgh", 12),
        row("ij", 12),
        blank(12),
      ]

  test "wide characters wrap by display width":
    check render("    日本語のテキストです", 12) ==
      @[blank(12), row("日本語のテ", 12), row("キストです", 12), blank(12)]
    check render("    a日本語のテキ", 12) ==
      @[blank(12), row("a日本語の", 12), row("テキ", 12), blank(12)]

  test "grapheme clusters are not split":
    let flag = "\u{1F1EF}\u{1F1F5}" # one 2-column cluster of two code points
    check render("    123456789" & flag, 12) ==
      @[blank(12), row("123456789", 12), row(flag, 12), blank(12)]

  test "every row fills the width exactly, in the block's style":
    let md = "    let x = 1\n\n    let y = \"a long line that wraps\"\n    日本語"
    for width in [4, 8, 20, 33, 79]:
      for line in styled(md, width):
        check line.plain.displayWidth == width
        check line.len == 1
        check line[0].style == shade
    for width in [1, 2, 3]: # too narrow for a wide character; narrow text fits
      for line in styled("    let x = 1", width):
        check line.plain.displayWidth == width
        check line.len == 1
        check line[0].style == shade

  test "the style can be overridden by a theme":
    check styleOf("    x", "x") == shade
    let theme = {"code_indented": Style(bold: true)}.toTable
    for line in renderDocument("    x", 10, theme):
      check line[0].style == Style(bold: true)

  test "the example renders":
    let lines = render(example("code_indented"), 40)
    check lines.len > 0
    for line in lines:
      check line.displayWidth <= 40
