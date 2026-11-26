import std/unittest
import ../helpers
import nimslides/features/html_inline # only this feature is registered

proc dump(nodes: seq[InlineNode]): string =
  ## e.g. "foo html(<a>)" and "comment(<!-- x -->)"
  for node in nodes:
    if node of HtmlInline:
      let h = HtmlInline(node)
      result.add (if h.comment: "comment(" else: "html(") & h.raw & ")"
    elif node of Text:
      result.add Text(node).text

proc inl(raw: string): string =
  parseInline(raw).dump

suite "inline HTML: CommonMark examples":
  test "open tags (613, 614)":
    check inl("<a><bab><c2c>") == "html(<a>)html(<bab>)html(<c2c>)"
    check inl("<a/><b2/>") == "html(<a/>)html(<b2/>)"

  test "whitespace and line endings inside tags (615)":
    check inl("<a  /><b2\ndata=\"foo\" >") == "html(<a  />)html(<b2\ndata=\"foo\" >)"

  test "attributes with all kinds of values (616)":
    let raw = "<a foo=\"bar\" bam = 'baz <em>\"</em>'\n_boolean zoop:33=zoop:33 />"
    check inl(raw) == "html(" & raw & ")"

  test "custom tag names (617)":
    check inl("Foo <responsive-image src=\"foo.jpg\" />") ==
      "Foo html(<responsive-image src=\"foo.jpg\" />)"

  test "invalid tag names stay literal (618)":
    check inl("<33> <__>") == "<33> <__>"

  test "invalid attribute names stay literal (619)":
    check inl("<a h*#ref=\"hi\">") == "<a h*#ref=\"hi\">"

  test "invalid attribute values stay literal (620)":
    check inl("<a href=\"hi'> <a href=hi'>") == "<a href=\"hi'> <a href=hi'>"

  test "invalid whitespace stays literal (621)":
    check inl("< a><\nfoo><bar/ >\n<foo bar=baz\nbim!bop />") ==
      "< a>< foo><bar/ > <foo bar=baz bim!bop />"

  test "attributes need whitespace between them (622)":
    check inl("<a href='bar'title=title>") == "<a href='bar'title=title>"

  test "closing tags (623, 624)":
    check inl("</a></foo >") == "html(</a>)html(</foo >)"
    check inl("</a href=\"foo\">") == "</a href=\"foo\">"

  test "comments (625, 626)":
    check inl("foo <!-- this is a --\ncomment - with hyphens -->") ==
      "foo comment(<!-- this is a --\ncomment - with hyphens -->)"
    check inl("foo <!--> foo -->") == "foo comment(<!-->)foo -->"
    check inl("foo <!---> foo -->") == "foo comment(<!--->)foo -->"

  test "processing instructions, declarations and CDATA (627, 628, 629)":
    check inl("foo <?php echo $a; ?>") == "foo html(<?php echo $a; ?>)"
    check inl("foo <!ELEMENT br EMPTY>") == "foo html(<!ELEMENT br EMPTY>)"
    check inl("foo <![CDATA[>&<]]>") == "foo html(<![CDATA[>&<]]>)"

  test "entities and backslashes stay as written inside tags (630, 631)":
    check inl("foo <a href=\"&ouml;\">") == "foo html(<a href=\"&ouml;\">)"
    check inl("foo <a href=\"\\*\">") == "foo html(<a href=\"\\*\">)"

  test "a backslash does not escape a quote (632)":
    check inl("<a href=\"\\\"\">") == "<a href=\"\"\">"

suite "inline HTML: edge cases":
  test "quoted values may contain >":
    check inl("<a title=\"1 > 0\" x='>'>") == "html(<a title=\"1 > 0\" x='>'>)"

  test "unterminated constructs stay literal":
    check inl("<a href=\"x") == "<a href=\"x"
    check inl("<!-- open") == "<!-- open"
    check inl("<?pi") == "<?pi"
    check inl("<![CDATA[x]]") == "<![CDATA[x]]"
    check inl("<!x") == "<!x"
    check inl("a < b > c") == "a < b > c"
    check inl("<") == "<"

  test "escaped < is not HTML":
    check inl("\\<b>") == "<b>"

  test "a declaration needs a letter after <!":
    check inl("<!1>") == "<!1>"

  test "a comment may contain -- but not -->":
    check inl("<!-- a -- b -->c") == "comment(<!-- a -- b -->)c"
    check inl("<!-- a --> b -->") == "comment(<!-- a -->)b -->"

suite "inline HTML: rendering":
  test "tags are hidden, the text between them is normal":
    check render("press <kbd>q</kbd> to quit") == @["press q to quit"]
    check styleOf("press <kbd>q</kbd>", "q") == Style()
    check render("<b\nclass=\"x\">y</b>") == @["y"]
    check render("rarer: <?pi ?>, <!DOCTYPE html>, <![CDATA[x]]>.") == @["rarer: , , ."]

  test "hidden HTML renders no spans":
    let ctx = LayoutCtx(width: 40, doc: newDocCtx())
    check HtmlInline(raw: "<b>").spans(ctx, Style(bold: true)).len == 0
    check HtmlInline(raw: "<!-- -->", comment: true).spans(ctx, Style()).len == 0

  test "hidden HTML leaves no double space":
    check render("a <!-- hidden --> b") == @["a b"]
    check render("a <br/> b") == @["a b"]
    check render("a<!-- hidden -->b") == @["ab"]
    check render("<!-- hidden --> starts") == @["starts"]
    check render("ends <!-- hidden -->") == @["ends"]
    check render("a <!-- x\ny --> b\nc <!-- z -->\nd") == @["a b c d"]
    check render("x <b> y</b> and <i>z</i> w") == @["x y and z w"]

  test "invalid HTML stays visible":
    check render("a < b > c, <33>") == @["a < b > c, <33>"]

  test "the example renders":
    check render(example("html_inline"), 60).len > 0
