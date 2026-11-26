import std/[os, sequtils, strutils, unittest]
import ../helpers
import nimslides/features/code_fenced # only this feature is registered

const shade = Style(fg: indexed(252), bg: indexed(235))
const langStyle = Style(italic: true, fg: indexed(243), bg: indexed(235))

proc blank(width = 20): string =
  ' '.repeat(width)

proc row(text: string, width = 20): string =
  ## A content row: 2 columns of padding, then `text`, shaded to `width`.
  "  " & text & ' '.repeat(width - 2 - text.displayWidth)

proc top(lang: string, width = 20): string =
  ' '.repeat(width - 2 - lang.len) & lang & "  "

proc code(md: string): FencedCode =
  let blocks = parse(md)
  check blocks.len == 1
  check blocks[0] of FencedCode
  FencedCode(blocks[0])

const noHighlighter = "nimslides-no-such-highlighter"
const fakeBat = currentSourcePath.parentDir.parentDir / "fixtures" / "fake_bat.sh"
const keyword = Style(bold: true, fg: indexed(81)) # what fake_bat.sh colors with

suite "fenced code":
  setup:
    highlighter = noHighlighter # plain cards, whether or not bat is installed

  test "backtick and tilde fences":
    check render("```\na\n```", 20) == @[blank(), row("a"), blank()]
    check render("~~~\na\n~~~", 20) == @[blank(), row("a"), blank()]
    check code("```\na\nb\n```").lines == @["a", "b"]
    check code("~~~~\n```\n~~~~").lines == @["```"]
    check code("```\n~~~\n```").lines == @["~~~"]

  test "fewer than 3 characters is no fence":
    check parse("``\na\n``")[0] of Paragraph

  test "a longer closing fence closes, a shorter one does not":
    check code("```\na\n`````").lines == @["a"]
    check code("````\na\n```\nb\n````").lines == @["a", "```", "b"]

  test "a closing fence has no info string":
    check code("```\na\n``` x\n```").lines == @["a", "``` x"]

  test "the language is the first word of the info string":
    check code("```nim\nx\n```").lang == "nim"
    check code("```  nim extra words \nx\n```").lang == "nim"
    check code("```  nim extra words \nx\n```").info == "nim extra words"
    check code("``` c\\+\\+\nx\n```").lang == "c++"
    check code("```\nx\n```").lang == ""
    check render("```nim\nx\n```", 20) == @[top("nim"), row("x"), blank()]

  test "a backtick fence's info string has no backticks":
    check parse("``` a`b\nx\n```")[0] of Paragraph
    check code("~~~ a`b\nx\n~~~").lang == "a`b"

  test "the fence's indentation is removed from the content":
    check code("  ```\n    a\n b\nc\n  ```").lines == @["  a", "b", "c"]
    check code("   ~~~\n  x\n   ~~~").lines == @["x"]
    check code("```\n  a\n   ```").lines == @["  a"]

  test "4 spaces of indentation is no fence":
    check parse("    ```\n    a\n    ```")[0] of Paragraph

  test "an unclosed fence runs to the end":
    check code("```\na\n\nb").lines == @["a", "", "b"]
    check code("```").lines.len == 0
    check render("```", 20) == @[blank(), blank()]

  test "a fence interrupts a paragraph":
    let blocks = parse("text\n```\ncode\n```\nmore")
    check blocks.len == 3
    check blocks[0] of Paragraph
    check blocks[1] of FencedCode
    check blocks[2] of Paragraph
    check render("text\n```\ncode\n```", 20) ==
      @["text", "", blank(), row("code"), blank()]

  test "the content is literal":
    let md = "```\n# title\n*em* `code` \\* <b>\n\n  - item\n```"
    check code(md).lines == @["# title", "*em* `code` \\* <b>", "", "  - item"]
    check render(md, 30) ==
      @[
        blank(30),
        row("# title", 30),
        row("*em* `code` \\* <b>", 30),
        blank(30),
        row("  - item", 30),
        blank(30),
      ]

  test "long lines are hard-wrapped, keeping whitespace":
    check render("```\n0123456789  abcdefghij\n```", 12) ==
      @[
        blank(12),
        row("0123456789", 12),
        row("  abcdefgh", 12),
        row("ij", 12),
        blank(12),
      ]

  test "wide characters wrap by display width":
    # 10 columns of code per row: 5 wide characters, or 4 after one narrow
    check render("```\n日本語のテキストです\n```", 12) ==
      @[blank(12), row("日本語のテ", 12), row("キストです", 12), blank(12)]
    check render("```\na日本語のテキ\n```", 12) ==
      @[blank(12), row("a日本語の", 12), row("テキ", 12), blank(12)]

  test "grapheme clusters are not split":
    let flag = "\u{1F1EF}\u{1F1F5}" # one 2-column cluster of two code points
    check render("```\n123456789" & flag & "\n```", 12) ==
      @[blank(12), row("123456789", 12), row(flag, 12), blank(12)]

  test "tabs are expanded like everywhere else":
    check code("```\n\tx\n```").lines == @["    x"]

  test "every row fills the width, in the block's styles":
    let md = "```nim\nlet x = 1\n\nlet y = \"a long line that wraps\"\n```"
    for width in [8, 20, 33]:
      for line in styled(md, width):
        check line.plain.displayWidth == width
        for span in line:
          check span.style in [shade, langStyle]
    let lines = styled(md, 20)
    check lines[0] ==
      @[
        Span(text: blank(15), style: shade),
        Span(text: "nim", style: langStyle),
        Span(text: "  ", style: shade),
      ]
    for line in lines[1 .. ^1]:
      check line.len == 1
      check line[0].style == shade
    check lines[1 .. ^1].mapIt(it.plain) ==
      @[
        row("let x = 1"),
        blank(),
        row("let y = \"a long li"),
        row("ne that wraps\""),
        blank(),
      ]

  test "a language too long for the row is cut":
    check render("```verylongname\nx\n```", 8)[0] == "verylo  "

  test "the example renders":
    check render(example("code_fenced"), 40).len > 0

suite "ANSI colors":
  test "plain text, one line per newline":
    check parseAnsi("a\nb") == @[@[Span(text: "a")], @[Span(text: "b")]]
    check parseAnsi("") == @[Line(@[])]
    check parseAnsi("a\n") == @[@[Span(text: "a")], Line(@[])]

  test "palette, truecolor and basic colors, fg and bg":
    check parseAnsi("\e[38;5;81mx") ==
      @[@[Span(text: "x", style: Style(fg: indexed(81)))]]
    check parseAnsi("\e[48;2;1;2;255mx") ==
      @[@[Span(text: "x", style: Style(bg: Color(kind: ckRgb, r: 1, g: 2, b: 255)))]]
    check parseAnsi("\e[31;102mx") ==
      @[@[Span(text: "x", style: Style(fg: indexed(1), bg: indexed(10)))]]
    check parseAnsi("\e[91;44mx") ==
      @[@[Span(text: "x", style: Style(fg: indexed(9), bg: indexed(4)))]]
    check parseAnsi("\e[38;5;999mx")[0][0].style == Style() # out of range

  test "attributes and resets":
    check parseAnsi("\e[1;2;3;4;9mx")[0][0].style ==
      Style(bold: true, dim: true, italic: true, underline: true, strikethrough: true)
    check parseAnsi("\e[1;3;4;9;31;41m\e[22;23;24;29;39;49mx")[0][0].style == Style()
    check parseAnsi("\e[1;31ma\e[0mb\e[mc") ==
      @[@[Span(text: "a", style: Style(bold: true, fg: indexed(1))), Span(text: "bc")]]

  test "styles carry across lines; other escapes are dropped":
    check parseAnsi("\e[1ma\nb") ==
      @[
        @[Span(text: "a", style: Style(bold: true))],
        @[Span(text: "b", style: Style(bold: true))],
      ]
    check parseAnsi("a\e[2Kb\e]x") == @[@[Span(text: "abx")]]

suite "syntax highlighting":
  setup:
    highlighter = fakeBat

  test "code with a language is colored over the card":
    let lines = styled("```nim\nlet x\n```", 20)
    check lines.mapIt(it.plain) == @[top("nim"), row("let x"), blank()]
    check lines[1] ==
      @[
        Span(text: "  ", style: shade),
        Span(text: "let x", style: shade.merge(keyword)),
        Span(text: blank(13), style: shade),
      ]

  test "wrapped rows keep their colors and the width":
    let md = "```nim\n0123456789abc\n\nx\n```"
    let lines = styled(md, 12)
    check lines.mapIt(it.plain) ==
      @[
        top("nim", 12),
        row("0123456789", 12),
        row("abc", 12),
        blank(12),
        row("x", 12),
        blank(12),
      ]
    check lines[2][1] == Span(text: "abc", style: shade.merge(keyword))
    for width in [3, 8, 12, 30]:
      check widths(md, width).allIt(it == width)

  test "plain when there is no language":
    check styled("```\nlet x\n```", 20)[1] == @[Span(text: row("let x"), style: shade)]

  test "plain when the highlighter fails or changes the text":
    check styled("```nope\nlet x\n```", 20)[1] ==
      @[Span(text: row("let x"), style: shade)]
    check styled("```mangle\nlet x\n```", 20)[1] ==
      @[Span(text: row("let x"), style: shade)]

  test "plain when the highlighter is not installed":
    highlighter = noHighlighter
    check styled("```nim\nlet x\n```", 20)[1] ==
      @[Span(text: row("let x"), style: shade)]

  test "the real bat, if installed":
    if findExe("bat") == "":
      skip()
    else:
      highlighter = "bat"
      let md = "```nim\nproc f(x: int) = echo \"hi\" # c\n```"
      let lines = styled(md, 40)
      check lines[1].plain == row("proc f(x: int) = echo \"hi\" # c", 40)
      check lines[1].len > 3
