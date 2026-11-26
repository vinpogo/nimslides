## Links, checked against CommonMark spec examples (0.31.2, "Links" and
## "Autolinks"; example numbers in comments) that need no other feature.

import std/[strutils, tables, unittest]
import ../helpers
import nimslides/features/links # only this feature is registered

proc dump(nodes: seq[InlineNode]): string =
  ## e.g. "a link(/u|t|text)"; nested links as "inner(...)".
  for node in nodes:
    if node of Link:
      let l = Link(node)
      let name = if l.nested: "inner" else: "link"
      result.add name & "(" & l.url
      if l.title.len > 0:
        result.add "|" & l.title
      result.add "|" & l.children.dump & ")"
    elif node of Text:
      result.add Text(node).text
    else:
      raiseAssert "unexpected node"

proc inl(md: string): string =
  ## The inlines of a one-paragraph document, reference definitions applied.
  let doc = newDocCtx()
  let blocks = parseDocument(md, doc)
  check blocks.len == 1
  parseInlines(Paragraph(blocks[0]).raw, doc).dump

const
  textStyle = Style(underline: true, fg: Color(kind: ckIndexed, index: 75))
  urlStyle = Style(fg: Color(kind: ckIndexed, index: 243))

suite "inline links":
  test "destination and title (482, 483, 486, 487)":
    check inl("[link](/uri \"title\")") == "link(/uri|title|link)"
    check inl("[link](/uri)") == "link(/uri|link)"
    check inl("[link]()") == "link(|link)"
    check inl("[link](<>)") == "link(|link)"

  test "no spaces in destinations unless in <> (488, 489, 490)":
    check inl("[link](/my uri)") == "[link](/my uri)"
    check inl("[link](</my uri>)") == "link(/my uri|link)"
    check inl("[link](foo\nbar)") == "[link](foo bar)"

  test "parentheses and escapes in destinations (494, 495, 496, 501)":
    check inl("[link](\\(foo\\))") == "link((foo)|link)"
    check inl("[link](foo(and(bar)))") == "link(foo(and(bar))|link)"
    check inl("[link](foo(and(bar))") == "[link](foo(and(bar))"
    check inl("[link](foo\\)\\:)") == "link(foo):|link)"

  test "titles in all three quotes (505)":
    check inl("[link](/url \"title\")") == "link(/url|title|link)"
    check inl("[link](/url 'title')") == "link(/url|title|link)"
    check inl("[link](/url (title))") == "link(/url|title|link)"

  test "whitespace around the destination (511)":
    check inl("[link](   /uri\n  \"title\"  )") == "link(/uri|title|link)"

  test "space between text and destination is not a link (512)":
    check inl("[link] (/uri)") == "[link] (/uri)"

  test "brackets in link text (513, 514, 515, 516)":
    check inl("[link [foo [bar]]](/uri)") == "link(/uri|link [foo [bar]])"
    check inl("[link] bar](/uri)") == "[link] bar](/uri)"
    check inl("[link [bar](/uri)") == "[link link(/uri|bar)"
    check inl("[link \\[bar](/uri)") == "link(/uri|link [bar)"

suite "reference links":
  test "full reference (526, 532)":
    check inl("[link][foo]\n\n[foo]: /url \"title\"") == "link(/url|title|link)"
    check inl("[foo][BaR]\n\n[bar]: /url") == "link(/url|foo)"

  test "labels are normalised (541)":
    check inl("[Foo\n  bar]: /url\n\n[Baz][Foo bar]") == "link(/url|Baz)"

  test "no space between text and label (542)":
    check inl("[foo] [bar]\n\n[bar]: /url \"title\"") == "[foo] link(/url|title|bar)"

  test "first definition wins (544)":
    check inl("[foo]: /url1\n\n[foo]: /url2\n\n[bar][foo]") == "link(/url1|bar)"

  test "an undefined label is no link (545, 568)":
    check inl("[bar][foo\\!]\n\n[foo!]: /url") == "[bar][foo!]"
    check inl("[foo][bar][baz]\n\n[baz]: /url") == "[foo]link(/url|bar)"

  test "collapsed reference (553, 555)":
    check inl("[foo][]\n\n[foo]: /url \"title\"") == "link(/url|title|foo)"
    check inl("[Foo][]\n\n[foo]: /url \"title\"") == "link(/url|title|Foo)"

  test "shortcut reference (557, 560, 563)":
    check inl("[foo]\n\n[foo]: /url \"title\"") == "link(/url|title|foo)"
    check inl("[[bar [foo]\n\n[foo]: /url") == "[[bar link(/url|foo)"
    check inl("[foo] bar\n\n[foo]: /url") == "link(/url|foo) bar"

  test "undefined shortcut stays literal":
    check inl("[foo]") == "[foo]"
    check render("see [foo] here") == @["see [foo] here"]

  test "inner brackets are found when the outer ones are no link":
    check inl("[[foo]]\n\n[foo]: /url") == "[link(/url|foo)]"

suite "autolinks":
  test "URIs (594, 595, 596, 598, 600)":
    check inl("<http://foo.bar.baz>") == "link(http://foo.bar.baz|http://foo.bar.baz)"
    check inl("<https://foo.bar.baz/test?q=hello&id=22&boolean>") ==
      "link(https://foo.bar.baz/test?q=hello&id=22&boolean|https://foo.bar.baz/test?q=hello&id=22&boolean)"
    check inl("<irc://foo.bar:2233/baz>") ==
      "link(irc://foo.bar:2233/baz|irc://foo.bar:2233/baz)"
    check inl("<a+b+c:d>") == "link(a+b+c:d|a+b+c:d)"
    check inl("<made-up-scheme://foo,bar>") ==
      "link(made-up-scheme://foo,bar|made-up-scheme://foo,bar)"

  test "emails get mailto (603, 604)":
    check inl("<foo@bar.example.com>") ==
      "link(mailto:foo@bar.example.com|foo@bar.example.com)"
    check inl("<foo+special@Bar.baz-bar0.com>") ==
      "link(mailto:foo+special@Bar.baz-bar0.com|foo+special@Bar.baz-bar0.com)"

  test "not autolinks (602, 605, 606, 607, 608, 609, 610)":
    check inl("<https://foo.bar/baz bim>") == "<https://foo.bar/baz bim>"
    check inl("<foo\\+@bar.example.com>") == "<foo+@bar.example.com>"
    check inl("<>") == "<>"
    check inl("< https://foo.bar >") == "< https://foo.bar >"
    check inl("<m:abc>") == "<m:abc>"
    check inl("<foo.bar.baz>") == "<foo.bar.baz>"
    check inl("https://example.com") == "https://example.com"

  test "backslashes are literal inside (601)":
    check inl("<https://example.com/\\[\\>") ==
      "link(https://example.com/\\[\\|https://example.com/\\[\\)"

  test "autolinks take precedence over link text":
    check inl("[foo<https://x.y/?a=]>") == "[foolink(https://x.y/?a=]|https://x.y/?a=])"

suite "nested links (simplification)":
  test "the outer link wins; inner links become its text":
    check inl("[foo [bar](/uri)](/uri2)") == "link(/uri2|foo inner(/uri|bar))"
    check inl("[a <https://x.y> b](/u)") == "link(/u|a inner(https://x.y|https://x.y) b)"

  test "inner links draw as link text without their url":
    check render("[foo [bar](/uri)](/u)") == @["foo bar (/u)"]

suite "rendering":
  test "the url follows the text":
    check render("see [Nim](https://nim-lang.org) now", 60) ==
      @["see Nim (https://nim-lang.org) now"]

  test "no url when the text is the url":
    check render("[https://x.y](https://x.y)") == @["https://x.y"]
    check render("<https://x.y>") == @["https://x.y"]
    check render("<me@x.y>") == @["me@x.y"]
    check render("[me@x.y](mailto:me@x.y)") == @["me@x.y"]

  test "no url when it is empty":
    check render("[link]()") == @["link"]

  test "a different text with a mailto url shows it":
    check render("[mail me](mailto:me@x.y)") == @["mail me (mailto:me@x.y)"]

  test "styles":
    let md = "*x* [a `b`](/u) c"
    check styleOf(md, "a") == textStyle
    check styleOf(md, "(/u)") == urlStyle
    check styleOf(md, " c") == Style()

  test "the link style goes on top of the surrounding style":
    let theme =
      {"paragraph": Style(bold: true, fg: Color(kind: ckIndexed, index: 1))}.toTable
    let line = renderDocument("[a](/u)", 40, theme)[0]
    check line[0].style == Style(bold: true, underline: true, fg: textStyle.fg)
    check line[^1].style == Style(bold: true, fg: urlStyle.fg)

  test "the url wraps like a word":
    check render("some [text](https://example.com/a/long/path)", 20) ==
      @["some text", "(https://example.com", "/a/long/path)"]
    for width in 5 .. 40:
      for line in styled(example("links"), width):
        check line.plain.displayWidth <= width

  test "the example renders":
    check render(example("links"), 60).len > 0
    check "[" notin render("[a](/b) [c][] [d]\n\n[c]: /c\n[d]: /d").join
