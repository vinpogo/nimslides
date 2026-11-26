import std/unittest
import nimslides/render

suite "frontmatter":
  test "title and author are read; the rest is the body":
    let (meta, body) = splitFrontmatter("---\ntitle: Nim\nauthor: Vin\n---\n\n# One")
    check meta == Frontmatter(title: "Nim", author: "Vin")
    check body == "\n# One"

  test "quotes and surrounding spaces are removed":
    let meta = splitFrontmatter("---\ntitle:  \"a: b\"  \nauthor: 'Vin'\n---").meta
    check meta == Frontmatter(title: "a: b", author: "Vin")

  test "other keys, comments, lists and nested values are ignored":
    let src =
      "---\n# a comment\nmarp: true\ntags:\n  - title: no\n- x\ntitle: Nim\n---\nbody"
    check splitFrontmatter(src) == (Frontmatter(title: "Nim"), "body")

  test "`...` closes it too; trailing spaces are fine":
    check splitFrontmatter("---  \ntitle: Nim\n...\nbody") ==
      (Frontmatter(title: "Nim"), "body")

  test "an empty frontmatter":
    check splitFrontmatter("---\n---\nbody") == (Frontmatter(), "body")

  test "without one, the source is unchanged":
    for src in [
      "",
      "# One",
      "text\n---\ntitle: x\n---",
      "---\ntitle: x\nno closing fence",
      "---\n\ntitle: x\n---", # `---` + blank line is a slide separator
      " ---\ntitle: x\n---",
    ]:
      check splitFrontmatter(src) == (Frontmatter(), src)
