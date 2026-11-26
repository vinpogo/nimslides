## Theme files, the default theme, and the slide background. All features
## are registered here, as in the binary.

import std/[os, strutils, tables, unittest]
import nimslides/[render, theme]
import nimslides/core/registry # registered.styles

const root = currentSourcePath().parentDir / ".."

proc errorOf(text: string): string =
  try:
    discard parseTheme(text, "t.ini")
  except ThemeError as e:
    return e.msg
  raiseAssert "no ThemeError for " & text.escape

suite "parseColor":
  test "names, palette indexes, hex and default":
    check parseColor("default") == Color()
    check parseColor("red") == indexed(1)
    check parseColor("bright_white") == indexed(15)
    check parseColor("Black") == indexed(0)
    check parseColor("208") == indexed(208)
    check parseColor("#FF5fd7") == Color(kind: ckRgb, r: 255, g: 95, b: 215)

  test "bad colors are rejected":
    for bad in ["", "256", "-1", "#12345", "#gg0000", "pink", "bright_"]:
      expect ValueError:
        discard parseColor(bad)

suite "parseTheme":
  test "patches only the attributes it names":
    let t = parseTheme("[heading.1]\nfg = \"#000000\"\n")
    check t["heading.1"] == Style(bold: true, fg: Color(kind: ckRgb, r: 0, g: 0, b: 0))
    check "heading.2" notin t

  test "false switches an attribute off; default resets a color":
    let t = parseTheme("[strong]\nbold = false\n[code_span]\nbg = default\n")
    check t["strong"] == Style()
    check t["code_span"].bg == Color()
    check t["code_span"].fg == registered.styles["code_span"].fg

  test "an empty section keeps the default":
    check parseTheme("[paragraph]\n")["paragraph"] == registered.styles["paragraph"]

  test "errors name the file and line":
    check errorOf("[heading.1]\n[headin.2]\n").startsWith(
      "t.ini:2: unknown style key \"headin.2\""
    )
    check errorOf("[strong]\n\ncolour = red\n").startsWith(
      "t.ini:3: unknown attribute \"colour\""
    )
    check errorOf("[strong]\nfg = pink\n").startsWith("t.ini:2: fg: bad color")
    check errorOf("[strong]\nbold = yes\n").startsWith("t.ini:2: bold: expected true")
    check errorOf("fg = red\n").startsWith("t.ini:1: `fg` comes before any [section]")
    check errorOf("[strong]\nbold\n").startsWith("t.ini:2: expected `name = value`")
    check errorOf("[strong]\nbold =  # x\n").startsWith("t.ini:2: `bold` has no value")
    check errorOf("[strong]\n\n# c\n[nope] # c\n").startsWith(
      "t.ini:4: unknown style key"
    )
    check errorOf("[strong\n").startsWith("t.ini:1: expected `[style.key]`")
    check errorOf("[strong]\nfg = \"red\n").startsWith("t.ini:2: fg: bad quoting")

  test "comments, quotes and unquoted hex colors":
    let t = parseTheme(
      "; theme\n[strong]  # c\nfg = #0000ff  # blue\nbg = \"#00ff00\" ; green\nbold=false\n"
    )
    check t["strong"] ==
      Style(
        fg: Color(kind: ckRgb, r: 0, g: 0, b: 255),
        bg: Color(kind: ckRgb, r: 0, g: 255, b: 0),
      )

  test "loadTheme reports unreadable files":
    expect ThemeError:
      discard loadTheme(root / "no-such-theme.ini")

  test "the light example theme loads":
    check loadTheme(root / "examples" / "themes" / "light.ini")["slide"].bg ==
      indexed(255)

suite "default theme":
  test "themes/default.ini is up to date (regenerate: nimslides --print-theme)":
    check readFile(root / "themes" / "default.ini") == defaultTheme()

  test "lists every registered key, and reads back as the defaults":
    let t = parseTheme(defaultTheme())
    check t.len == registered.styles.len
    check t == registered.styles

  test "rgb colors survive the round trip":
    let styles = {"strong": Style(fg: Color(kind: ckRgb, r: 1, g: 171, b: 255))}.toTable
    check parseTheme(formatTheme(styles), defaults = styles) == styles

suite "slide style":
  let theme = parseTheme("[slide]\nfg = 252\nbg = 17\n")

  test "every span, margin included, gets the slide's colors":
    let slide = renderSlides("a *b*\n\nc", 40, theme)[0]
    check slide.style == Style(fg: indexed(252), bg: indexed(17))
    for line in slide.lines:
      for span in line:
        check span.style.bg == indexed(17)
        check span.style.fg == indexed(252)
    check slide.lines[0][^1].style.italic

  test "a span's own colors win":
    let code = parseTheme("[code_span]\nfg = 1\nbg = 2\n")
    var both = theme
    both["code_span"] = code["code_span"]
    for span in renderSlides("`x`", 40, both)[0].lines[0]:
      if span.text == "x":
        check span.style.bg == indexed(2)
        check span.style.fg == indexed(1)

  test "without a theme, slides keep the terminal's colors":
    check renderSlides("a", 40)[0].style == Style()
    check renderSlides("a", 40)[0].lines[0][0].style == Style()

  test "the footer styles":
    check Theme().themed("footer") == Style()
    check Theme().themed("footer.counter") == Style(dim: true)
    let t = parseTheme("[footer]\nbg = 4\n[footer.counter]\nfg = 3\n")
    check t.themed("footer").bg == indexed(4)
    check t.themed("footer.counter") == Style(dim: true, fg: indexed(3))
