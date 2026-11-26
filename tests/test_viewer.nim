import std/unittest
import pkg/celina/core/colors
import nimslides/[render, viewer]

suite "toCelina":
  test "the default style maps to the terminal defaults":
    check render.Style().toCelina ==
      colors.Style(
        fg: ColorValue(kind: Default), bg: ColorValue(kind: Default), modifiers: {}
      )

  test "maps a 256-color index":
    let c = render.Color(kind: ckIndexed, index: 208)
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
