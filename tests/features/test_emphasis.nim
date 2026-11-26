## Emphasis and strong emphasis, checked against CommonMark spec examples
## (0.31.2, "Emphasis and strong emphasis"; example numbers in comments).

import std/[strutils, tables, unittest]
import ../helpers
import nimslides/features/emphasis

proc dump(nodes: seq[InlineNode]): string =
  ## The node structure, e.g. "a em(b strong(c))".
  for node in nodes:
    if node of Text:
      result.add Text(node).text
    elif node of Emphasis:
      result.add "em(" & Emphasis(node).children.dump & ")"
    elif node of Strong:
      result.add "strong(" & Strong(node).children.dump & ")"
    else:
      raiseAssert "unexpected node"

proc inl(raw: string): string =
  parseInline(raw).dump

const
  em = Style(italic: true)
  strong = Style(bold: true)
  both = Style(bold: true, italic: true)

proc runs(md: string, theme = initTable[string, Style]()): seq[(string, Style)] =
  ## The spans of a one-line document as (text, style), neighbours with the
  ## same style joined.
  for line in renderDocument(md, 80, theme):
    for span in line:
      result.add (span.text, span.style)

suite "emphasis: structure":
  test "single forms":
    check inl("*a*") == "em(a)" # 350
    check inl("_a_") == "em(a)" # 360
    check inl("**a**") == "strong(a)" # 378
    check inl("__a__") == "strong(a)" # 387
    check inl("***a***") == "em(strong(a))" # cf. 416

  test "nesting":
    check inl("**a *b* c**") == "strong(a em(b) c)" # cf. 431
    check inl("*a **b** c*") == "em(a strong(b) c)" # cf. 412
    check inl("**bold *nested* bold**") == "strong(bold em(nested) bold)"
    check inl("*(*foo*)*") == "em((em(foo)))" # 368
    check inl("__foo, __bar__, baz__") == "strong(foo, strong(bar), baz)" # 397
    check inl("*foo**bar**baz*") == "em(foostrong(bar)baz)" # 412
    check inl("foo***bar***baz") == "fooem(strong(bar))baz" # 416
    check inl("**foo *bar **baz**\nbim* bop**") ==
      "strong(foo em(bar strong(baz) bim) bop)" # 423

  test "not flanking: stays literal":
    check inl("a * b") == "a * b" # cf. 351
    check inl("a * foo bar*") == "a * foo bar*" # 352
    check inl("** foo bar**") == "** foo bar**" # 379
    check inl("_ foo bar_") == "_ foo bar_" # 359
    check inl("*foo bar *") == "*foo bar *" # 365

  test "unmatched delimiters stay literal":
    check inl("**open") == "**open"
    check inl("close*") == "close*"
    check inl("**foo*") == "*em(foo)" # 445
    check inl("*foo**") == "em(foo)*" # 452
    check inl("__foo_") == "_em(foo)" # 457

  test "_ is not intraword, * is":
    check inl("snake_case_word") == "snake_case_word" # cf. 363
    check inl("in*tra*word") == "inem(tra)word" # 357
    check inl("foo__bar__") == "foo__bar__" # 391
    check inl("foo**bar**") == "foostrong(bar)" # 383
    check inl("_foo_bar_baz_") == "em(foo_bar_baz)" # 374
    check inl("пристаням_стремятся_") ==
      "пристаням_стремятся_" # 364

  test "punctuation: flanking around brackets":
    check inl("*(foo)*") == "em((foo))" # 367
    check inl("a*\"foo\"*") == "a*\"foo\"*" # 354
    check inl("_(bar)_.") == "em((bar))." # 376

  test "the rule of 3":
    check inl("*foo**bar*") == "em(foo**bar)" # 411
    check inl("*foo**bar***") == "em(foostrong(bar))" # 414
    check inl("foo***bar***baz") == "fooem(strong(bar))baz" # 416
    check inl("foo******bar*********baz") == "foostrong(strong(strong(bar)))***baz" # 417
    check inl("*foo**bar**baz*") == "em(foostrong(bar)baz)" # 412

  test "escapes stay literal":
    check inl("\\*not em*") == "*not em*"
    check inl("*\\**") == "em(*)" # 459

suite "emphasis: rendering":
  test "plain text drops the delimiters":
    check render("*a* _b_ **c** __d__ ***e***") == @["a b c d e"]
    check render("**a *b* c**") == @["a b c"]
    check render("snake_case_word a * b **open") == @["snake_case_word a * b **open"]

  test "em is italic, strong is bold, nested combines":
    check runs("x *a* y") == @[("x ", Style()), ("a", em), (" y", Style())]
    check runs("x **a** y") == @[("x ", Style()), ("a", strong), (" y", Style())]
    check runs("***a***") == @[("a", both)]
    check runs("**a *b* c**") == @[("a ", strong), ("b", both), (" c", strong)]
    check runs("*a **b** c*") == @[("a ", em), ("b", both), (" c", em)]
    check runs("foo***bar***baz") == @[
      ("foo", Style()), ("bar", both), ("baz", Style())
    ]

  test "styles merge with the surrounding base style":
    let red = Style(fg: Color(kind: ckIndexed, index: 1))
    let theme = {"paragraph": red}.toTable
    check runs("a *b* **c**", theme) ==
      @[
        ("a ", red),
        ("b", Style(italic: true, fg: red.fg)),
        (" ", red),
        ("c", Style(bold: true, fg: red.fg)),
      ]

  test "theme overrides the style keys":
    let blue = Style(fg: Color(kind: ckIndexed, index: 4))
    let theme = {"emphasis": blue, "strong": Style(underline: true)}.toTable
    check runs("*a* **b** ***c***", theme) ==
      @[
        ("a", blue),
        (" ", Style()),
        ("b", Style(underline: true)),
        (" ", Style()),
        ("c", Style(underline: true, fg: blue.fg)),
      ]

  test "emphasis wraps across lines":
    check render("*one two three*", 8) == @["one two", "three"]
    check styleOf("*one two three*", "three", 8) == em

  test "the example renders":
    let lines = render(example("emphasis"), 60)
    check lines.len > 0
    for line in lines:
      check "**" notin line
