{.warning[UnusedImport]: off.}

import std/unittest
import ./helpers
import nimslides/core/discover

importAll("fixtures/features") # probe.nim, and a README.md to skip
importAll("fixtures/missing") # a missing folder imports nothing

suite "importAll":
  test "imports each module in the folder, which registers itself":
    check rules.inlineRules.len == 1
    check render("a @ b") == @["a <probe> b"]
