# Package

version       = "0.1.0"
author        = "vingy"
description   = "Render markdown files as slides in the terminal"
license       = "GPL-3.0-or-later"
srcDir        = "src"
bin           = @["nimslides"]


# Dependencies

requires "nim >= 2.2.0"
requires "celina == 0.17.0"
requires "unicodedb >= 0.13.2" # core measures text widths like celina does


# Tasks

import std/[os, strutils]

task test, "Run the tests in tests/ and tests/features/":
  # nimble's own test task does not look into subfolders.
  for dir in ["tests", "tests/features"]:
    for file in listFiles(dir):
      let name = file.extractFilename
      if name.startsWith("test_") and name.endsWith(".nim"):
        exec "nim c -r --hints:off " & file
