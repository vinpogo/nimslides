## Core's shared link parsing (core/links.nim), without any feature: link
## text, inline destinations and titles, reference definitions and lookup.

import std/unittest
import ./helpers

type Link = ref object of InlineNode # what the test-only rule builds
  url: string
  children: seq[InlineNode]

method spans(node: Link, ctx: LayoutCtx, base: Style): seq[Span] =
  node.children.spans(ctx, base) & @[Span(text: "<" & node.url & ">", style: base)]

proc docWith(md: string): DocCtx =
  ## A document context holding the definitions found in `md`.
  result = newDocCtx()
  discard parseDocument(md, result)

proc text(src: string, start = 0): string =
  ## The link text at `start`, or "-" if there is none.
  let t = linkText(src, start)
  if t.found: t.text else: "-"

proc target(src: string): string =
  ## "url|title|rest" for an inline tail at the start of `src`, or "-".
  let t = inlineTarget(src, 0)
  if t.found:
    t.url & "|" & t.title & "|" & src[t.stop .. ^1]
  else:
    "-"

proc tail(src: string, defs = ""): string =
  ## "url|title|rest" for link text plus tail at the start of `src`, with the
  ## definitions in `defs`, or "-".
  let p = InlineParser(src: src, doc: docWith(defs))
  let t = p.parseLinkTail(p.linkText)
  if t.found:
    t.url & "|" & t.title & "|" & src[t.stop .. ^1]
  else:
    "-"

suite "link text":
  test "finds the matching bracket":
    check text("[a] b") == "a"
    check text("[]") == ""
    check text("[a [b] c] d]") == "a [b] c"
    check text("[[a]]") == "[a]"
    check text("[a [b]") == "-"
    check text("a [b]") == "-"
    check text("a [b]", 2) == "b"
    check linkText("[ab](x)", 0).stop == 4

  test "escaped brackets don't count":
    check text("[a\\]b]") == "a\\]b"
    check text("[a\\[b]") == "a\\[b"
    check text("[a\\]") == "-"
    check text("[a\\\\]") == "a\\\\" # an escaped backslash, then the bracket

  test "code spans hide brackets":
    check text("[a `]` b]") == "a `]` b"
    check text("[a ``x]`y`` b]") == "a ``x]`y`` b"
    check text("[a `b](/u)` c") == "-" # the code span takes the bracket
    check text("[a `b] c") == "a `b" # an unclosed backtick run is literal
    check text("[a \\`]` b]") == "a \\`" # an escaped backtick opens nothing

  test "works from an inline parser":
    let p = InlineParser(src: "x![alt](i.png)", pos: 1)
    check linkText(p.src, p.pos + 1).text == "alt"
    p.pos = 2
    check p.linkText.text == "alt"

suite "inline destination and title":
  test "bare destinations, balanced parentheses":
    check target("(/u)x") == "/u||x"
    check target("()") == "||"
    check target("(a(b)c)") == "a(b)c||"
    check target("(a(b(c)))") == "a(b(c))||"
    check target("(a(b)") == "-"
    check target("(a\\(b)") == "a(b||"
    check target("(a b)") == "-"
    check target("(/u") == "-"

  test "pointy destinations":
    check target("(<a b>)") == "a b||"
    check target("(<>)") == "||"
    check target("(<a\\>b>)") == "a>b||"
    check target("(<a<b>)") == "-"
    check target("(<a\nb>)") == "-"
    check target("(<a>b)") == "-"

  test "titles in three quote styles, with escapes":
    check target("(/u \"t\")") == "/u|t|"
    check target("(/u 't')") == "/u|t|"
    check target("(/u (t))") == "/u|t|"
    check target("(/u \"a \\\"q\\\" b\")") == "/u|a \"q\" b|"
    check target("(/u (a(b)))") == "-"
    check target("(/u \"t)") == "-"
    check target("(/u \"t\" x)") == "-"
    check target("(/u\"t\")") == "/u\"t\"||" # no space: part of the destination
    check target("(<u>\"t\")") == "-"

  test "whitespace with up to one line ending":
    check target("(  /u  \"t\"  )") == "/u|t|"
    check target("(\n/u\n\"t\"\n)") == "/u|t|"
    check target("(/u\n\n\"t\")") == "-"
    check target("(/u \"a\nb\")") == "/u|a\nb|"

  test "escapes resolve in destination and title":
    check target("(/a\\*b \"\\*t\\*\")") == "/a*b|*t*|"
    check target("(/a\\b)") == "/a\\b||" # not ASCII punctuation: kept

  test "only at an opening parenthesis":
    check target("x(/u)") == "-"
    check inlineTarget("[a](/u)", 3).url == "/u"

suite "reference definitions":
  test "taken from the start of a paragraph":
    let doc = docWith("[foo]: /url \"title\"\n[bar]: <b c> 'x'\nrest")
    check doc.lookupReference("foo") ==
      LinkTarget(found: true, url: "/url", title: "title")
    check doc.lookupReference("bar") == LinkTarget(found: true, url: "b c", title: "x")
    check render("[foo]: /url \"title\"\n[bar]: <b c> 'x'\nrest") == @["rest"]

  test "not in the middle of a paragraph":
    let md = "text\n[foo]: /url"
    check not docWith(md).lookupReference("foo").found
    check render(md) == @["text [foo]: /url"]

  test "title, destination and label may be on following lines":
    let doc = docWith("[a]:\n/u\n\"long\ntitle\"\n[b\nc]: /v\n(t)")
    check doc.lookupReference("a") ==
      LinkTarget(found: true, url: "/u", title: "long\ntitle")
    check doc.lookupReference("b c") == LinkTarget(found: true, url: "/v", title: "t")
    check render("[a]: /u\n\"t\"\nrest") == @["rest"]

  test "a title followed by text":
    # On the next line: the definition ends before the title.
    check render("[a]: /u\n\"t\" more") == @["\"t\" more"]
    check docWith("[a]: /u\n\"t\" more").lookupReference("a").title == ""
    # On the same line: no definition at all.
    check render("[a]: /u \"t\" more") == @["[a]: /u \"t\" more"]
    check not docWith("[a]: /u \"t\" more").lookupReference("a").found

  test "invalid definitions stay text":
    for md in [
      "[a]:", "[a]: <b", "[]: /u", "[ ]: /u", "[a[b]]: /u", "[a] : /u", "[a]: /u x",
      "[a]: <x>y",
    ]:
      check render(md) == @[md]
    check render("[a]: <>") == newSeq[string]() # an empty pointy destination
    check docWith("[a]: <>").lookupReference("a") == LinkTarget(found: true)

  test "first definition wins":
    let doc = docWith("[a]: /one\n[A]: /two\n\n[a]: /three")
    check doc.lookupReference("a").url == "/one"
    check not doc.defineReference("a", "/four")
    check doc.defineReference("new", "/five", "t")
    check doc.lookupReference("NEW") == LinkTarget(
      found: true, url: "/five", title: "t"
    )

  test "labels are normalised":
    check normalizeLabel("  Foo \t BAR\nbaz ") == "foo bar baz"
    check normalizeLabel("ÄÖÜ") == "äöü"
    let doc = docWith("[Foo   Bar]: /u")
    check doc.lookupReference("foo bar").found
    check doc.lookupReference(" FOO\nbar ").found
    check not doc.lookupReference("foobar").found
    check not doc.lookupReference("").found

  test "escapes resolve, but labels match unresolved":
    let doc = docWith("[a\\!]: /u\\*v \"t\\\"\"")
    check doc.lookupReference("a\\!") ==
      LinkTarget(found: true, url: "/u*v", title: "t\"")
    check not doc.lookupReference("a!").found

  test "a paragraph of definitions only disappears":
    check parse("[a]: /u\n[b]: /v").len == 0
    check render("[a]: /u\n[b]: /v") == newSeq[string]()
    check render("x\n\n[a]: /u\n\ny") == @["x", "", "y"]
    check render("x\n\n[a]: /u\n[b]: /v") == @["x"]

suite "link tails":
  const defs = "[foo]: /f \"T\"\n[bar]: /b\n[x y]: /xy"

  test "inline form":
    check tail("[a](/u 't') z", defs) == "/u|t| z"
    check tail("[foo](/u)", defs) == "/u||"

  test "full reference":
    check tail("[a][foo] z", defs) == "/f|T| z"
    check tail("[a][X  Y]", defs) == "/xy||"
    check tail("[a][nope]", defs) == "-"
    check tail("[foo][nope]", defs) == "-" # a label follows: no shortcut

  test "collapsed reference":
    check tail("[Foo][] z", defs) == "/f|T| z"
    check tail("[nope][]", defs) == "-"

  test "shortcut reference":
    check tail("[foo] z", defs) == "/f|T| z"
    check tail("[x\ny]", defs) == "/xy||"
    check tail("[nope]", defs) == "-"
    check tail("[foo][ ]", defs) == "/f|T|[ ]" # `[ ]` is not a label

  test "an invalid inline tail falls back to references":
    check tail("[foo](not a link)", defs) == "/f|T|(not a link)"
    check tail("[a](not a link)", defs) == "-"

  test "no link text, no tail":
    let p = InlineParser(src: "(/u)", doc: newDocCtx())
    check not p.parseLinkTail(LinkText()).found

  test "a rule built on the helpers":
    let empty = snapshot()
    registerInline InlineRule(
      name: "testlink",
      triggers: {'['},
      parse: proc(p: InlineParser): InlineNode =
        let text = p.linkText
        let target = p.parseLinkTail(text)
        if target.found:
          result = Link(url: target.url, children: p.parseInlines(text.text))
          p.pos = target.stop
      ,
    )
    check render("see [a](/u), [foo] and [b][bar].\n\n" & defs, 60) ==
      @["see a</u>, foo</f> and b</b>."]
    check render("[foo][nope][x y]\n\n" & defs, 60) == @["[foo]nope</xy>"]
    check render("[[foo]]\n\n" & defs, 60) == @["[foo</f>]"]
    restore empty
