import std/[sequtils, strutils, unittest]
import ../helpers
import nimslides/features/html # only this feature is registered

proc shape(md: string): seq[string] =
  ## Each top-level block as "html<kind>: <raw>" or "p: <raw>".
  for b in parse(md):
    if b of HtmlBlock:
      let h = HtmlBlock(b)
      result.add "html" & $h.kind & ": " & h.lines.join("\n")
    elif b of Paragraph:
      result.add "p: " & Paragraph(b).raw
    else:
      result.add "?"

suite "html blocks: CommonMark examples":
  test "148: type 6 ends at a blank line, type 1 inside it does not count":
    check shape(
      "<table><tr><td>\n<pre>\n**Hello**,\n\n_world_.\n</pre>\n</td></tr></table>"
    ) ==
      @[
        "html6: <table><tr><td>\n<pre>\n**Hello**,", "p: _world_.\n</pre>",
        "html6: </td></tr></table>",
      ]

  test "149: indented lines belong to the block":
    check shape(
      "<table>\n  <tr>\n    <td>\n           hi\n    </td>\n  </tr>\n</table>\n\nokay."
    ) ==
      @[
        "html6: <table>\n  <tr>\n    <td>\n           hi\n    </td>\n  </tr>\n</table>",
        "p: okay.",
      ]

  test "150-151: up to 3 spaces of indent, closing tags start blocks too":
    check shape(" <div>\n  *hello*\n         <foo><a>") ==
      @["html6:  <div>\n  *hello*\n         <foo><a>"]
    check shape("</div>\n*foo*") == @["html6: </div>\n*foo*"]

  test "152, 155: markdown between blank lines is a paragraph":
    check shape("<DIV CLASS=\"foo\">\n\n*Markdown*\n\n</DIV>") ==
      @["html6: <DIV CLASS=\"foo\">", "p: *Markdown*", "html6: </DIV>"]
    check shape("<div>\n*foo*\n\n*bar*") == @["html6: <div>\n*foo*", "p: *bar*"]

  test "153-158: type 6 needs only the tag name":
    check shape("<div id=\"foo\"\n  class=\"bar\">\n</div>")[0].startsWith("html6")
    check shape("<div id=\"foo\"\n*hi*") == @["html6: <div id=\"foo\"\n*hi*"]
    check shape("<div class\nfoo") == @["html6: <div class\nfoo"]
    check shape("<div *???-&&&-<---\n*foo*") == @["html6: <div *???-&&&-<---\n*foo*"]

  test "161: everything up to the blank line, even a fence":
    check shape("<div></div>\n``` c\nint x = 33;\n```") ==
      @["html6: <div></div>\n``` c\nint x = 33;\n```"]

  test "162-166: type 7 is a complete tag alone on its line":
    check shape("<a href=\"foo\">\n*bar*\n</a>") ==
      @["html7: <a href=\"foo\">\n*bar*\n</a>"]
    check shape("<Warning>\n*bar*\n</Warning>")[0].startsWith("html7")
    check shape("<i class=\"foo\">\n*bar*\n</i>")[0].startsWith("html7")
    check shape("</ins>\n*bar*") == @["html7: </ins>\n*bar*"]
    check shape("<del>\n\n*foo*\n\n</del>") ==
      @["html7: <del>", "p: *foo*", "html7: </del>"]

  test "168: a tag followed by text is not a block":
    check shape("<del>*foo*</del>") == @["p: <del>*foo*</del>"]

  test "169-172: type 1 runs to its closing tag, across blank lines":
    check shape(
      "<pre language=\"haskell\"><code>\nimport Text.HTML.TagSoup\n\nmain :: IO ()\n</code></pre>\nokay"
    ) ==
      @[
        "html1: <pre language=\"haskell\"><code>\nimport Text.HTML.TagSoup\n\nmain :: IO ()\n</code></pre>",
        "p: okay",
      ]
    check shape("<textarea>\n\n*foo*\n\n</textarea>") ==
      @["html1: <textarea>\n\n*foo*\n\n</textarea>"]
    check shape("<style\n  type=\"text/css\">\nh1 {color:red;}\n\np {}\n</STYLE>\nokay").len ==
      2

  test "173: unclosed type 1 runs to the end":
    check shape("<style\n  type=\"text/css\">\n\nfoo") ==
      @["html1: <style\n  type=\"text/css\">\n\nfoo"]

  test "176-178: the end condition can be on the first line, text after it stays":
    check shape("<style>p{color:red;}</style>\n*foo*") ==
      @["html1: <style>p{color:red;}</style>", "p: *foo*"]
    check shape("<!-- foo -->*bar*\n*baz*") == @["html2: <!-- foo -->*bar*", "p: *baz*"]
    check shape("<script>\nfoo\n</script>1. *bar*") ==
      @["html1: <script>\nfoo\n</script>1. *bar*"]

  test "179-182: types 2-5":
    check shape("<!-- Foo\n\nbar\n   baz -->\nokay") ==
      @["html2: <!-- Foo\n\nbar\n   baz -->", "p: okay"]
    check shape("<?php\n\n  echo '>';\n\n?>\nokay") ==
      @["html3: <?php\n\n  echo '>';\n\n?>", "p: okay"]
    check shape("<!DOCTYPE html>") == @["html4: <!DOCTYPE html>"]
    check shape("<![CDATA[\nif (a < b) {\n\n}\n]]>\nokay") ==
      @["html5: <![CDATA[\nif (a < b) {\n\n}\n]]>", "p: okay"]

  test "183-184: four spaces of indent is not HTML":
    check shape("  <!-- foo -->\n\n    <!-- foo -->") ==
      @["html2:   <!-- foo -->", "p: <!-- foo -->"]
    check shape("  <div>\n\n    <div>") == @["html6:   <div>", "p: <div>"]

  test "186, 189-190: blank lines split blocks":
    check shape("<div>\nbar\n</div>\n*foo*") == @["html6: <div>\nbar\n</div>\n*foo*"]
    check shape("<table>\n\n<tr>\n\n<td>\nHi\n</td>\n\n</tr>\n\n</table>").len == 5

suite "html blocks: interrupting a paragraph":
  test "185: types 1-6 interrupt":
    check shape("Foo\n<div>\nbar\n</div>") == @["p: Foo", "html6: <div>\nbar\n</div>"]
    check shape("Foo\n<!-- x -->\nbar") == @["p: Foo", "html2: <!-- x -->", "p: bar"]
    check shape("Foo\n<pre>\nx\n</pre>")[1].startsWith("html1")
    check shape("Foo\n<?x ?>")[1].startsWith("html3")
    check shape("Foo\n<!X>")[1].startsWith("html4")
    check shape("Foo\n<![CDATA[ x ]]>")[1].startsWith("html5")

  test "187: type 7 does not":
    check shape("Foo\n<a href=\"bar\">\nbaz") == @["p: Foo\n<a href=\"bar\">\nbaz"]

suite "html blocks: start conditions":
  test "type 1 needs a delimiter after the tag name":
    check shape("<pre>")[0].startsWith("html1")
    check shape("<prefix>")[0].startsWith("html7")
    check shape("<pre/>") == @["p: <pre/>"]
    check shape("</pre>") == @["p: </pre>"]

  test "type 6 accepts />, rejects longer names":
    check shape("<hr/>")[0].startsWith("html6")
    check shape("<divx>")[0].startsWith("html7")

  test "type 7 attributes":
    check shape("<a b='c' d=e f>")[0].startsWith("html7")
    check shape("<x-y :z/>")[0].startsWith("html7")
    check shape("<a b=>") == @["p: <a b=>"]
    check shape("<a \"b\">") == @["p: <a \"b\">"]
    check shape("<a> text") == @["p: <a> text"]
    check shape("<1a>") == @["p: <1a>"]

suite "html blocks: rendering":
  test "comments render nothing":
    check render("<!-- note -->") == newSeq[string]()
    check render("<!--\nspeaker notes\n\nmore notes\n-->") == newSeq[string]()
    check render("  <!-- a --> <!-- b -->") == newSeq[string]()
    check render("<!-->") == newSeq[string]()

  test "no extra blank rows around a hidden comment":
    check render("before\n\n<!-- note -->\n\nafter") == @["before", "", "after"]
    check render("before\n<!-- note -->\nafter") == @["before", "", "after"]
    check render("<!-- a -->\n\nonly") == @["only"]
    check render("only\n\n<!-- a -->") == @["only"]

  test "a comment with text after it is shown raw":
    check render("<!-- foo -->*bar*") == @["<!-- foo -->*bar*"]

  test "other blocks show their raw text":
    check render("<div>\n  *hi*\n</div>") == @["<div>", "  *hi*", "</div>"]
    check render("<pre>\na\n\nb\n</pre>") == @["<pre>", "a", "", "b", "</pre>"]
    check styleOf("<div>", "<div>") == Style(fg: indexed(243))

  test "long lines hard-wrap and keep within the width":
    check render("<div class=\"abcdefghij\">", 10) ==
      @["<div class", "=\"abcdefgh", "ij\">"]
    let md = example("html")
    for width in 1 .. 60:
      for line in styled(md, width):
        check line.plain.displayWidth <= width

  test "the example renders without its comments":
    let lines = render(example("html"), 60)
    check lines.len > 0
    check not lines.anyIt("speaker notes:" in it or "several lines" in it)
