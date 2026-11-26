import std/[sequtils, strutils, unittest]
import ../helpers
import nimslides/features/table

proc w(s: string): int =
  s.displayWidth

suite "table":
  let empty = snapshot()
  setup:
    restore empty

  test "GFM 198: a basic table":
    check render("| foo | bar |\n| --- | --- |\n| baz | bim |") ==
      @[
        "╭─────┬─────╮", "│ foo │ bar │",
        "├─────┼─────┤", "│ baz │ bim │",
        "╰─────┴─────╯",
      ]
    check parse("| foo | bar |\n| --- | --- |\n| baz | bim |")[0] of GfmTable

  test "GFM 199: alignment, pipes optional":
    let t = GfmTable(parse("| abc | defghi |\n:-: | -----------:\nbar | baz")[0])
    check t.aligns == @[alCenter, alRight]
    check render("| abc | defghi |\n:-: | -----------:\nbar | baz") ==
      @[
        "╭─────┬────────╮", "│ abc │ defghi │",
        "├─────┼────────┤", "│ bar │    baz │",
        "╰─────┴────────╯",
      ]

  test "GFM 200: escaped pipes":
    let md = "| f\\|oo  |\n| ------ |\n| b `\\|` az |\n| b **\\|** im |"
    let t = GfmTable(parse(md)[0])
    check t.header == @["f|oo"]
    check t.rows == @[@["b `|` az"], @["b **|** im"]]
    check render(md)[1] == "│ f|oo       │"

  test "GFM 201: another block ends the table":
    registerBlock BlockRule(
      name: "test.quote",
      priority: 50,
      interruptsParagraph: true,
      parse: proc(p: BlockParser): BlockNode =
        if p.line.startsWith(">"):
          p.advance
          result = Paragraph(raw: "quote")
      ,
    )
    let blocks = parse("| abc | def |\n| --- | --- |\n| bar | baz |\n> bar")
    check blocks.len == 2
    check GfmTable(blocks[0]).rows == @[@["bar", "baz"]]

  test "GFM 202: a line without pipes is a row, a blank line ends the table":
    let blocks = parse("| abc | def |\n| --- | --- |\n| bar | baz |\nbar\n\nbar")
    check blocks.len == 2
    check GfmTable(blocks[0]).rows == @[@["bar", "baz"], @["bar", ""]]
    check blocks[1] of Paragraph

  test "GFM 203: not a table when the cell counts differ":
    let blocks = parse("| abc | def |\n| --- |\n| bar |")
    check blocks.len == 1
    check blocks[0] of Paragraph

  test "GFM 204: rows are padded or cut to the column count":
    let md = "| abc | def |\n| --- | --- |\n| bar |\n| bar | baz | boo |"
    check GfmTable(parse(md)[0]).rows == @[@["bar", ""], @["bar", "baz"]]
    check render(md)[3 .. 4] == @["│ bar │     │", "│ bar │ baz │"]

  test "GFM 205: a header without body rows":
    check render("| abc | def |\n| --- | --- |") ==
      @[
        "╭─────┬─────╮", "│ abc │ def │",
        "├─────┼─────┤",
        "╰─────┴─────╯",
      ]

  test "alignment of each kind":
    let md =
      "| l | c | r | n |\n|:--|:-:|--:|---|\n| xxxxx | xxxxx | xxxxx | xxxxx |\n| a | b | c | d |"
    check GfmTable(parse(md)[0]).aligns == @[alLeft, alCenter, alRight, alNone]
    check render(md)[4] == "│ a     │   b   │     c │ d     │"

  test "delimiter rows":
    check parse("a | b\n--|--")[0] of GfmTable
    check parse("| a |\n| - |")[0] of GfmTable
    check parse("| a |\n|:-:|")[0] of GfmTable
    check parse("| a | b |\n| --- | -x- |")[0] of Paragraph
    check parse("| a | b |\n| --- | : |")[0] of Paragraph
    check parse("| a | b |\n| --- |  |")[0] of Paragraph

  test "a heading underline is not a table":
    check parse("Title\n---")[0] of Paragraph # no heading feature: paragraph

  test "tables do not interrupt paragraphs":
    let blocks = parse("text\n| a | b |\n| - | - |")
    check blocks.len == 1
    check blocks[0] of Paragraph

  test "four spaces of indent is not a table":
    check not (parse("    | a |\n    | - |")[0] of GfmTable)

  test "escapes other than pipes stay for the inline parser":
    let t = GfmTable(parse("| \\*a\\* | b\\\\|\n| - | - |")[0])
    check t.header == @["\\*a\\*", "b\\\\"]
    check render("| \\*a\\* | b |\n| - | - |")[1] == "│ *a* │ b │"

  test "cells are inline-parsed":
    registerInline InlineRule(
      name: "test.at",
      triggers: {'@'},
      priority: 99,
      parse: proc(p: InlineParser): InlineNode =
        p.pos += 1
        Text(text: "AT"),
    )
    check render("| a@b |\n| - |\n| @ |")[1 .. 3] ==
      @["│ aATb │", "├──────┤", "│ AT   │"]

  test "styles":
    let md = "| head |\n| - |\n| body |"
    check styleOf(md, "╭") == Style(fg: indexed(240))
    check styleOf(md, "│") == Style(fg: indexed(240))
    check styleOf(md, "head") == Style(bold: true, fg: indexed(81))
    check styleOf(md, "body") == Style()

  test "wide tables shrink the widest column and wrap its cells":
    let md = "| k | text |\n| - | ---- |\n| x | one two three four five six |"
    check render(md, 20) ==
      @[
        "╭───┬──────────────╮",
        "│ k │ text         │",
        "├───┼──────────────┤",
        "│ x │ one two      │", "│   │ three four   │",
        "│   │ five six     │",
        "╰───┴──────────────╯",
      ]

  test "every row is exactly the table width, never wider than the slide":
    let md =
      "| Option | Description | Default |\n| :-- | :-: | --: |\n" &
      "| `--width` | Sets the width of the slide in columns. | terminal |\n" &
      "| 日本語のテキスト | 👨‍👩‍👧 emoji 😀 | x |\n| a |"
    for width in 1 .. 70:
      let lines = render(md, width)
      let tw = lines[0].w
      check tw <= width
      for line in lines:
        check line.w == tw

  test "the widest column shrinks first":
    let lines = render("| aaaaaaaa | bbbbbbbbbbbbbbbbbbbb |\n| - | - |", 22)
    check lines[0] ==
      "╭─────────┬──────────╮"

  test "columns go below 3 only when all are at 3":
    check render("| aaaaaa | bbbbbb |\n| - | - |", 13)[0] ==
      "╭─────┬─────╮"
    check render("| aaaaaa | bbbbbb |\n| - | - |", 12)[0] ==
      "╭────┬─────╮"
    check render("| a | bbbbbb |\n| - | - |", 12)[0] ==
      "╭───┬──────╮"

  test "the example renders":
    let lines = render(example("table"), 60)
    check lines.anyIt("╭" in it)
    check lines.allIt(it.w <= 60)
