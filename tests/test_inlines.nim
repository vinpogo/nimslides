## The inline driver, with delimiter and inline rules registered by this
## file only (no real features are imported).

import std/[strutils, unittest]
import ./helpers

type
  Delimited = ref object of InlineNode # what the test delimiter rules build
    tag: string
    children: seq[InlineNode]

  Code = ref object of InlineNode # what the test inline rule builds
    text: string

method spans(node: Delimited, ctx: LayoutCtx, base: Style): seq[Span] =
  node.children.spans(ctx, base.merge(Style(italic: true)))

method spans(node: Code, ctx: LayoutCtx, base: Style): seq[Span] =
  @[Span(text: node.text, style: base.merge(Style(dim: true)))]

proc dump(nodes: seq[InlineNode]): string =
  ## e.g. "a em(b strong(c))"
  for node in nodes:
    if node of Text:
      result.add Text(node).text
    elif node of Code:
      result.add "code(" & Code(node).text & ")"
    elif node of Delimited:
      result.add Delimited(node).tag & "(" & Delimited(node).children.dump & ")"

proc delimited(names: array[3, string]): proc(n: int, c: seq[InlineNode]): InlineNode =
  result = proc(n: int, c: seq[InlineNode]): InlineNode =
    Delimited(tag: names[n], children: c)

let empty = snapshot()

proc registerTestRules() =
  registerDelimiter(
    DelimiterRule(
      name: "star",
      ch: '*',
      intraword: true,
      ruleOf3: true,
      build: delimited(["", "em", "strong"]),
    )
  )
  registerDelimiter(
    DelimiterRule(
      name: "underscore",
      ch: '_',
      intraword: false,
      ruleOf3: true,
      build: delimited(["", "em", "strong"]),
    )
  )
  registerDelimiter(
    DelimiterRule(
      name: "tilde",
      ch: '~',
      intraword: true,
      sameLength: true,
      maxRun: 2,
      build: delimited(["", "del", "del"]),
    )
  )
  registerInline(
    InlineRule(
      name: "code",
      triggers: {'`'},
      parse: proc(p: InlineParser): InlineNode =
        let close = p.src.find('`', p.pos + 1)
        if close < 0:
          return nil
        result = Code(text: p.src[p.pos + 1 ..< close])
        p.pos = close + 1,
    )
  )

proc inl(raw: string): string =
  parseInline(raw).dump

suite "core inlines":
  setup:
    restore empty

  test "plain text and soft line breaks":
    check inl("a b") == "a b"
    check inl("one  \n   two\nthree") == "one two three"

  test "backslash escapes ASCII punctuation only":
    check inl("\\*a\\* \\\\ \\[x\\]") == "*a* \\ [x]"
    check inl("\\a \\é") == "\\a \\é"

  test "without delimiter rules, emphasis syntax stays literal":
    check inl("*a* **b** _c_ ~~d~~") == "*a* **b** _c_ ~~d~~"

suite "delimiter machinery":
  setup:
    restore empty
    registerTestRules()

  test "matches runs into nodes the feature builds":
    check inl("*a*") == "em(a)"
    check inl("**a**") == "strong(a)"
    check inl("***a***") == "em(strong(a))"
    check inl("_a_ __b__") == "em(a) strong(b)"

  test "flanking: runs next to spaces don't open or close":
    check inl("a * b *") == "a * b *"
    check inl("* a*") == "* a*"
    check inl("*(a)*") == "em((a))"

  test "* works inside words, _ does not":
    check inl("foo*bar*baz") == "fooem(bar)baz"
    check inl("foo_bar_baz") == "foo_bar_baz"
    check inl("snake_case_words") == "snake_case_words"
    check inl("_(a)_b") == "_(a)_b"

  test "nesting and unequal runs":
    check inl("*foo **bar** baz*") == "em(foo strong(bar) baz)"
    check inl("**foo*") == "*em(foo)"
    check inl("*foo**") == "em(foo)*"
    check inl("**a *b***") == "strong(a em(b))"

  test "the rule of 3":
    check inl("*foo**bar*") == "em(foo**bar)"
    check inl("*foo**bar**baz*") == "em(foo strong(bar) baz)".replace(" ", "")

  test "same-length runs with a maximum (GFM strikethrough style)":
    check inl("~a~ ~~b~~") == "del(a) del(b)"
    check inl("~~a~") == "~~a~"
    check inl("~~~a~~~") == "~~~a~~~"

  test "escaped delimiters stay literal":
    check inl("\\*a*") == "*a*"

  test "inline rules take their text before delimiters see it":
    check inl("*a`*`") == "*acode(*)"
    check inl("`a` and `b") == "code(a) and `b"

  test "nodes render through their spans method":
    check styleOf("x *a* y", "a") == Style(italic: true)
    check styleOf("x **`c`** y", "c") == Style(italic: true, dim: true)
    check styleOf("x *a* y", "x") == Style()

suite "inline rule order":
  setup:
    restore empty

  test "rules on the same trigger run by priority, then name":
    proc rule(name: string, priority: int, match: bool): InlineRule =
      InlineRule(
        name: name,
        triggers: {'@'},
        priority: priority,
        parse: proc(p: InlineParser): InlineNode =
          if match:
            inc p.pos
            result = Text(text: name)
          else:
            p.pos = p.src.len # must be undone by core
        ,
      )

    registerInline rule("b", 10, true)
    registerInline rule("a", 10, true)
    registerInline rule("first", 5, false)
    check registered.inlineRules[0].name == "first"
    check inl("x@y") == "xay"
