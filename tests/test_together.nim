## Features working together: every feature is registered here, as in the
## binary. Feature tests register only their own feature.

import std/unittest
import ./helpers
import nimslides/features

const nbsp = " "

suite "features together":
  test "a link in an image's alt text shows its text, not its url":
    check render("![see [the docs](/docs) here](/i.png)", 60) ==
      @["▨" & nbsp & "see the docs here (/i.png)"]

  test "lazy lines continue a paragraph inside nested containers":
    # CommonMark 259: the innermost open paragraph takes the lazy line.
    check render("> - > a\nb") == @["▎ • ▎ a b"]
    check render("> - a\nb") == @["▎ • a b"]
    check render("- > a\nb") == @["• ▎ a b"]
    check render("- a\n  > b\nc\n- d") == @["• a", "  ▎ b c", "• d"]

  test "a lazy line is never a setext underline":
    check render("> a\n===") == @["▎ a ==="]
    check render("- a\n===") == @["• a ==="]
