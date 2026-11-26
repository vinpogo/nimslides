## Core's HTML tag grammar (core/html.nim), shared by the html and
## html_inline features.

import std/unittest
import ./helpers

suite "html tag grammar":
  test "tag names start with a letter":
    check "div-1 x".tagNameEnd(0) == 5
    check "1div".tagNameEnd(0) == 0
    check "".tagNameEnd(0) == 0

  test "open tags with attributes":
    for tag in [
      "<a>", "<br/>", "<br />", "<a href=\"x\">", "<a href='x' title=y>",
      "<a\n  href=\"x\"\n>", "<x-y _a:b.c-d = \"v\" e>", "<img src=\"a > b\">",
    ]:
      check tag.openTagEnd(0) == tag.len
    check "x <b> y".openTagEnd(2) == 5

  test "not open tags":
    for tag in [
      "<33>", "< a>", "<a href='x'title=y>", "<a href=>", "<a h=\"x>", "<a/ >",
      "<a b=`c`>", "a>", "<",
    ]:
      check tag.openTagEnd(0) == -1

  test "closing tags":
    check "</a>".closingTagEnd(0) == 4
    check "</a \n>".closingTagEnd(0) == 6
    check "</a b>".closingTagEnd(0) == -1
    check "</>".closingTagEnd(0) == -1
    check "<a>".closingTagEnd(0) == -1

  test "tagEnd takes either":
    check "<a b='c'>".tagEnd(0) == 9
    check "</a>x".tagEnd(0) == 4
    check "<!-- x -->".tagEnd(0) == -1
