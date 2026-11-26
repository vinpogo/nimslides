## Word wrapping, display widths (checked against celina), block stacking
## and style lookup.

import std/[sequtils, strutils, tables, unicode, unittest]
import pkg/celina/core/buffer as celina
import ./helpers
import nimslides/core/width as ours

proc wrapped(text: string, width: int): seq[string] =
  wrap(@[Span(text: text)], width).mapIt(it.plain)

const tricky = [
  "", "plain ascii", "äöüß", "é", "à́b", "日本語", "ｶﾀｶﾅ",
  "한국어", "👍", "👍🏽", "👨‍👩‍👧", "🏳️‍🌈",
  "🇦🇹🇩🇪", "❤️", "❤︎", "☝🏽", "1️⃣", "#⃣", "x⃣",
  "A‍👍", "​", "­", "tab\there", "mixed 日本 👍🏽 é", "กำ", "நி",
  "🧑🏽‍💻 dev",
]

suite "display width":
  test "matches celina's for tricky strings":
    for s in tricky:
      checkpoint s.escape
      check ours.displayWidth(s) == celina.displayWidth(s)

  test "splits grapheme clusters like celina":
    for s in tricky:
      checkpoint s.escape
      var mine, theirs: seq[(string, int)]
      for (text, w) in s.clusters:
        mine.add (text, w)
      for (_, text, w) in s.toRunes.graphemeClusters:
        theirs.add (text, w)
      check mine == theirs

  test "wide characters, emoji clusters and combining marks":
    check ours.displayWidth("日本") == 4
    check ours.displayWidth("👍🏽") == 2
    check ours.displayWidth("👨‍👩‍👧") == 2
    check ours.displayWidth("é") == 1

suite "wrap":
  test "greedy at spaces":
    check wrapped("aa bb cc dd", 5) == @["aa bb", "cc dd"]
    check wrapped("aa bb cc dd", 4) == @["aa", "bb", "cc", "dd"]
    check wrapped("", 4).len == 0

  test "drops spaces at line edges, keeps them between words":
    check wrapped("  aa  bb   ", 10) == @["aa  bb"]
    check wrapped("aa    bb", 4) == @["aa", "bb"]

  test "splits words longer than a line":
    check wrapped("abcdefgh ij", 3) == @["abc", "def", "gh", "ij"]
    check wrapped("x abcdef", 4) == @["x", "abcd", "ef"]

  test "counts wide characters and never splits a cluster":
    check wrapped("日本語テキスト", 5) == @["日本", "語テ", "キス", "ト"]
    check wrapped("👨‍👩‍👧👨‍👩‍👧", 3) ==
      @["👨‍👩‍👧", "👨‍👩‍👧"]
    check wrapped("ééé", 2) == @["éé", "é"]
    check wrapped("日", 1) == @["日"] # too wide for any line: shown anyway

  test "keeps styles across lines and merges equal neighbours":
    let bold = Style(bold: true)
    let lines =
      wrap(@[Span(text: "aa b"), Span(text: "b cc", style: bold), Span(text: "c")], 4)
    check lines ==
      @[
        @[Span(text: "aa")],
        @[Span(text: "b"), Span(text: "b", style: bold)],
        @[Span(text: "cc", style: bold), Span(text: "c")],
      ]

  test "a newline in a span forces a break":
    check wrapped("aa\nbb cc", 10) == @["aa", "bb cc"]

type Probe = ref object of BlockNode

var seen: seq[(int, int)] # (width, depth) of each Probe laid out

method layout(node: Probe, ctx: LayoutCtx): seq[Line] =
  seen.add (ctx.width, ctx.depth)
  @[@[Span(text: "p")]]

suite "blocks and styles":
  test "renderBlocks narrows and deepens the context":
    let ctx = newLayoutCtx(20, newDocCtx())
    check ctx.renderBlocks(@[BlockNode(Probe()), Probe()], 10).mapIt(it.plain) ==
      @["p", "", "p"]
    check ctx.renderBlocks(@[BlockNode(Probe()), Probe()], 10, gap = 0).len == 2
    check seen[0] == (10, 1)

  test "style lookup: theme, then default, then plain":
    defaultStyle("test.key", Style(bold: true))
    var ctx = newLayoutCtx(10, newDocCtx())
    check ctx.style("test.key") == Style(bold: true)
    check ctx.style("unknown") == Style()
    ctx.theme["test.key"] = Style(dim: true)
    check ctx.style("test.key") == Style(dim: true)
