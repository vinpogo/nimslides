import std/unittest
import pkg/celina/core/[buffer, colors, events]
import nimslides/[render, viewer]

suite "toCelina":
  test "the default style maps to the terminal defaults":
    check render.Style().toCelina ==
      colors.Style(
        fg: ColorValue(kind: Default), bg: ColorValue(kind: Default), modifiers: {}
      )

  test "maps a 256-color index":
    let c = render.indexed(208)
    check c.toCelina == ColorValue(kind: Indexed256, indexed256: 208)
    check render.Style(bg: c).toCelina.bg ==
      ColorValue(kind: Indexed256, indexed256: 208)

  test "maps an RGB color":
    let c = render.Color(kind: ckRgb, r: 1, g: 128, b: 255)
    let want = ColorValue(kind: Rgb, rgb: RgbColor(r: 1, g: 128, b: 255))
    check c.toCelina == want
    check render.Style(fg: c).toCelina.fg == want
    check render.Style(fg: c).toCelina.bg == ColorValue(kind: Default)

  test "maps each attribute to its modifier":
    check render.Style(bold: true).toCelina.modifiers == {Bold}
    check render.Style(italic: true).toCelina.modifiers == {Italic}
    check render.Style(underline: true).toCelina.modifiers == {Underline}
    check render.Style(dim: true).toCelina.modifiers == {Dim}
    check render.Style(strikethrough: true).toCelina.modifiers == {Crossed}
    let all = render.Style(
      bold: true, italic: true, underline: true, dim: true, strikethrough: true
    )
    check all.toCelina.modifiers == {Bold, Italic, Underline, Dim, Crossed}

proc key(code: KeyCode, ch = ""): Event =
  Event(kind: Key, key: KeyEvent(code: code, char: ch))

proc ch(c: string): Event =
  key(Char, c)

proc wheel(button: MouseButton, kind = Press): Event =
  Event(kind: Mouse, mouse: MouseEvent(kind: kind, button: button))

suite "scrolling":
  const height = 10

  test "arrows and j/k scroll one line":
    check key(ArrowDown).scrollDelta(height) == 1
    check key(ArrowUp).scrollDelta(height) == -1
    check ch("j").scrollDelta(height) == 1
    check ch("k").scrollDelta(height) == -1

  test "PageUp/PageDown scroll a page, keeping one line of context":
    check key(PageDown).scrollDelta(height) == 9
    check key(PageUp).scrollDelta(height) == -9
    check key(PageDown).scrollDelta(1) == 1 # a one-row window still pages

  test "the wheel and touchpad scroll a few lines":
    check wheel(WheelDown).scrollDelta(height) == WheelLines
    check wheel(WheelUp).scrollDelta(height) == -WheelLines

  test "other input doesn't scroll":
    for e in [
      ch("x"),
      ch("g"),
      ch("G"),
      key(Space),
      key(Home),
      key(End),
      key(Enter),
      wheel(Left),
      wheel(Left, Release),
      wheel(NoButton, Move),
      Event(kind: Resize),
    ]:
      check e.scrollDelta(height) == 0

  test "scrolling stops at both ends":
    # 50 lines in 10 rows: offsets run from 0 to 40.
    check 0.scrolled(1, 50, height) == 1
    check 0.scrolled(-1, 50, height) == 0
    check 3.scrolled(-9, 50, height) == 0
    check 35.scrolled(9, 50, height) == 40
    check 40.scrolled(WheelLines, 50, height) == 40

  test "a slide that fits doesn't scroll":
    check 0.scrolled(1, 5, height) == 0
    check 0.scrolled(9, 10, height) == 0

suite "slides":
  test "right, l, n and space go to the next slide":
    for e in [key(ArrowRight), key(Space), ch(" "), ch("l"), ch("n")]:
      check e.slideDelta == 1

  test "left, h, p and backspace go to the previous slide":
    for e in [key(ArrowLeft), key(Backspace), ch("h"), ch("p")]:
      check e.slideDelta == -1

  test "scrolling keys don't change slides":
    for e in [key(ArrowDown), key(PageUp), ch("j"), ch("q"), wheel(WheelDown)]:
      check e.slideDelta == 0

  test "the counter shows the slide number, only for decks":
    check counter(0, 1) == ""
    check counter(0, 3) == "1/3"
    check counter(2, 3) == "3/3"

suite "paint":
  let bg = render.Style(bg: render.indexed(17))

  test "the slide background fills short lines, blank lines and below":
    let slide = Slide(lines: @[@[Span(text: "ab", style: bg)], @[]], style: bg)
    var buf = newBuffer(5, 4)
    buf.paint(slide, 0, 4)
    check buf[0, 0].symbol == "a"
    for (x, y) in [(4, 0), (0, 1), (4, 3)]:
      check buf[x, y].symbol == " "
      check buf[x, y].style == bg.toCelina

  test "the footer fills the bottom row; the counter sits on it":
    let row = render.Style(bg: render.indexed(4))
    var buf = newBuffer(6, 2)
    buf.paintFooter("1/3", row, row.merge(render.Style(dim: true)))
    check buf[0, 1].symbol == " "
    check buf[0, 1].style == row.toCelina
    check buf[5, 1].style == row.toCelina
    check buf[2, 1].symbol == "1"
    check buf[2, 1].style.bg == row.toCelina.bg
    check Dim in buf[2, 1].style.modifiers
    check buf[0, 0].style == render.Style().toCelina # only the bottom row

  test "a single slide has no footer":
    var buf = newBuffer(6, 2)
    buf.paintFooter("", render.Style(bg: render.indexed(4)), render.Style())
    check buf[0, 1].style == render.Style().toCelina
