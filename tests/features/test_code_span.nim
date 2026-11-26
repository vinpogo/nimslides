import std/unittest
import ../helpers
import nimslides/features/code_span # only this feature is registered

type Em = ref object of InlineNode # built by the test-only `*` rule
  children: seq[InlineNode]

method spans(node: Em, ctx: LayoutCtx, base: Style): seq[Span] =
  node.children.spans(ctx, base.merge(Style(italic: true)))

proc dump(nodes: seq[InlineNode]): string =
  ## e.g. "a code(b) em(c)"
  for node in nodes:
    if node of CodeSpan:
      result.add "code(" & CodeSpan(node).text & ")"
    elif node of Em:
      result.add "em(" & Em(node).children.dump & ")"
    elif node of Text:
      result.add Text(node).text

proc inl(raw: string): string =
  parseInline(raw).dump

let codeStyle =
  Style(fg: Color(kind: ckIndexed, index: 216), bg: Color(kind: ckIndexed, index: 236))

let withCodeSpan = snapshot()

suite "code span: CommonMark examples":
  setup:
    restore withCodeSpan

  test "simple span (328)":
    check inl("`foo`") == "code(foo)"
    check parseInline("`foo`")[0] of CodeSpan

  test "longer runs allow backticks inside (329, 339, 340)":
    check inl("`` foo ` bar ``") == "code(foo ` bar)"
    check inl("``foo`bar``") == "code(foo`bar)"
    check inl("` foo `` bar `") == "code(foo `` bar)"

  test "one space stripped from each side (330, 331, 332)":
    check inl("` `` `") == "code(``)"
    check inl("`  ``  `") == "code( `` )"
    check inl("` a`") == "code( a)"

  test "only spaces are stripped, not other whitespace (333)":
    let nbsp = " "
    check inl("`" & nbsp & "b" & nbsp & "`") == "code(" & nbsp & "b" & nbsp & ")"

  test "all-space content is not stripped (334)":
    check inl("` `\n`  `") == "code( ) code(  )"

  test "line endings become spaces (335, 336, 337)":
    # paragraph lines arrive with leading whitespace already stripped
    check inl("``\nfoo\nbar  \nbaz\n``") == "code(foo bar   baz)"
    check inl("``\nfoo \n``") == "code(foo )"
    check inl("`foo   bar \nbaz`") == "code(foo   bar  baz)"

  test "no backslash escapes inside (338)":
    check inl("`foo\\`bar`") == "code(foo\\)bar`"
    check inl("`\\*`") == "code(\\*)"

  test "precedence over later constructs (342, 343, 345)":
    check inl("[not a `link](/foo`)") == "[not a code(link](/foo))"
    check inl("`<a href=\"`\">`") == "code(<a href=\")\">`"
    check inl("`<https://foo.bar.`baz>`") == "code(<https://foo.bar.)baz>`"

  test "unmatched runs are literal (347, 348, 349)":
    check inl("```foo``") == "```foo``"
    check inl("`foo") == "`foo"
    check inl("`foo``bar``") == "`foocode(bar)"

  test "an escaped backtick does not start a run":
    check inl("\\`not code`") == "`not code`"
    check inl("\\``code`") == "`code(code)"

  test "inline syntax stays literal inside":
    check inl("`*not emphasis*`") == "code(*not emphasis*)"

suite "code span: with a test-only emphasis rule":
  setup:
    restore withCodeSpan
    registerDelimiter(
      DelimiterRule(
        name: "star",
        ch: '*',
        intraword: true,
        ruleOf3: true,
        build: proc(n: int, c: seq[InlineNode]): InlineNode =
          Em(children: c),
      )
    )

  test "code spans take precedence over emphasis delimiters (341)":
    check inl("*a `*` b*") == "em(a code(*) b)"
    check inl("*foo`*`") == "*foocode(*)"
    check inl("`*not emphasis*`") == "code(*not emphasis*)"
    check inl("*not `code*`") == "*not code(code*)"

  test "a code span inside emphasis keeps its colors and adds italic":
    var inEm = codeStyle
    inEm.italic = true
    check styleOf("*a `b` c*", "b") == inEm

suite "code span: rendering":
  setup:
    restore withCodeSpan

  test "the style key resolves to the default":
    let ctx = newLayoutCtx(40, newDocCtx())
    check ctx.style("code_span") == codeStyle
    check styleOf("run `nimble test` now", "nimble test") == codeStyle
    check styleOf("run `nimble test` now", "run") == Style()

  test "the content is one span":
    let line = styled("run `nimble test` now")[0]
    check line.len == 3
    check line[1] == Span(text: "nimble test", style: codeStyle)

  test "plain text output":
    check render("Use `x = 1` or ``a`b``, not `*x*`.") == @[
      "Use x = 1 or a`b, not *x*."
    ]
    check render("```foo`` and `bar") == @["```foo`` and `bar"]

  test "word wrap breaks at spaces inside code":
    check render("see `one two three` here", 12) == @["see one two", "three here"]
    let lines = styled("see `one two three` here", 12)
    check lines[1][0] == Span(text: "three", style: codeStyle)

  test "the example renders":
    check render(example("code_span"), 40).len > 0
