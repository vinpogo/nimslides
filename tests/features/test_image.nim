import std/[strutils, unittest]
import ../helpers
import nimslides/features/image # only this feature is registered

type Em = ref object of InlineNode # built by the test-only `*` rule
  children: seq[InlineNode]

method spans(node: Em, ctx: LayoutCtx, base: Style): seq[Span] =
  node.children.spans(ctx, base.merge(Style(italic: true)))

const nbsp = "\u00A0"

proc dump(nodes: seq[InlineNode]): string =
  ## e.g. `a img(/u "t": alt)`
  for node in nodes:
    if node of Image:
      let img = Image(node)
      result.add "img(" & img.url
      if img.title.len > 0:
        result.add " \"" & img.title & "\""
      result.add ": " & img.alt.dump & ")"
    elif node of Em:
      result.add "em(" & Em(node).children.dump & ")"
    elif node of Text:
      result.add Text(node).text

proc inl(raw: string): string =
  parseInline(raw).dump

proc show(md: string, width = 60): string =
  ## The rendered text with no-break spaces shown as plain spaces.
  render(md, width).join("\n").replace(nbsp, " ")

let imageStyle = Style(italic: true, fg: indexed(176))
let urlStyle = Style(fg: indexed(243))
let withImage = snapshot()

suite "image: CommonMark examples":
  setup:
    restore withImage

  test "inline images (572, 577, 578, 579)":
    check inl("![foo](/url \"title\")") == "img(/url \"title\": foo)"
    check inl("![foo](train.jpg)") == "img(train.jpg: foo)"
    check inl("My ![foo bar](/path/to/train.jpg  \"title\"   )") ==
      "My img(/path/to/train.jpg \"title\": foo bar)"
    check inl("![foo](<url>)") == "img(url: foo)"

  test "empty destination (580)":
    check inl("![](/url)") == "img(/url: )"

  test "nested brackets and images in the alt text (573, 574, 575)":
    check inl("![foo ![bar](/url)](/url2)") == "img(/url2: foo img(/url: bar))"
    check inl("![[foo]](/url)") == "img(/url: [foo])"

  test "reference images (576, 581, 582-591)":
    let defs = "\n\n[foo]: /url \"title\"\n[bar]: /url2\n[foo *bar*]: /url3"
    check show("![foo][bar]" & defs) == "▨ foo (/url2)"
    check show("![foo][]" & defs) == "▨ foo (/url)"
    check show("![foo]" & defs) == "▨ foo (/url)"
    check show("![Foo][]" & defs) == "▨ Foo (/url)" # labels ignore case
    check show("![foo *bar*]" & defs) == "▨ foo *bar* (/url3)"

  test "a label or [] after the text blocks the shortcut form (589)":
    check show("![foo] []\n\n[foo]: /url") == "▨ foo (/url) []"
    check show("![foo][nope]\n\n[foo]: /url") == "![foo][nope]"

  test "literal fallbacks (592, 593)":
    check inl("!") == "!"
    check inl("a ! b!") == "a ! b!"
    check inl("![foo]") == "![foo]" # no definition
    check inl("![foo](") == "![foo]("
    check inl("![foo](/a b)") == "![foo](/a b)"
    check inl("![") == "!["
    check inl("\\![foo](/url)") == "![foo](/url)" # escaped `!`
    check inl("!![a](/u)") == "!img(/u: a)"

suite "image: alt text":
  setup:
    restore withImage
    registerInline InlineRule(
      name: "test.em",
      triggers: {'*'},
      priority: 50,
      parse: proc(p: InlineParser): InlineNode =
        let close = p.src.find('*', p.pos + 1)
        if close > p.pos + 1:
          result = Em(children: p.parseInlines(p.src[p.pos + 1 ..< close]))
          p.pos = close + 1
      ,
    )

  test "alt text is parsed as inlines (576)":
    check inl("![foo *bar*](train.jpg)") == "img(train.jpg: foo em(bar))"

  test "alt text is flattened to plain text in the image style":
    let line = styled("![a *b* c](/u)", 60)[0]
    check line.len == 3
    check line[0] == Span(text: "▨" & nbsp & "a b c", style: imageStyle)
    check line[2] == Span(text: "(/u)", style: urlStyle)

  test "a nested image contributes only its alt text":
    check show("![foo ![bar](/url)](/url2)") == "▨ foo bar (/url2)"

  test "escapes and soft breaks in the alt text":
    check show("![a \\* b\nc](/u)") == "▨ a * b c (/u)"

suite "image: rendering":
  setup:
    restore withImage

  test "placeholder, alt text and url":
    check render("![A cat](cat.png)") == @["▨" & nbsp & "A cat (cat.png)"]
    check styleOf("![A cat](cat.png)", "cat.png") == urlStyle
    check styleOf("![A cat](cat.png)", "A cat") == imageStyle

  test "the title is kept but not shown":
    check show("![x](/u \"T\")") == "▨ x (/u)"

  test "empty alt text or url":
    check show("![](/u)") == "▨ (/u)"
    check show("![x]()") == "▨ x"

  test "the image style goes on top of the surrounding style":
    registerInline InlineRule(
      name: "test.em",
      triggers: {'*'},
      priority: 50,
      parse: proc(p: InlineParser): InlineNode =
        let close = p.src.find('*', p.pos + 1)
        if close > p.pos + 1:
          result = Em(children: p.parseInlines(p.src[p.pos + 1 ..< close]))
          p.pos = close + 1
      ,
    )
    var s = styleOf("*see ![x](/u) here*", "x")
    check s == imageStyle
    s = styleOf("*see ![x](/u) here*", "(/u)")
    check s == urlStyle.merge(Style(italic: true))

  test "the marker stays with the first word of the alt text when wrapping":
    let lines = render("aaaaaaa ![bb cc](/u)", 10)
    check lines == @["aaaaaaa", "▨" & nbsp & "bb cc", "(/u)"]

  test "rows never exceed the width":
    let md =
      "Text ![a long alt text with words](https://example.com/a/very/long/path.png) end"
    for width in 1 .. 50:
      for line in render(md, width):
        check line.displayWidth <= width

  test "the example renders":
    check render(example("image"), 40).len > 0
