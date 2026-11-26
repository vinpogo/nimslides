## Frontmatter: a block of `key: value` lines between `---` fences at the
## very start of the file, as in Jekyll, Marp and Slidev.
##
## ```markdown
## ---
## title: Nim in the terminal
## author: "Vin"
## ---
##
## # First slide
## ```
##
## Only `title` and `author` are read (they go in the footer); other keys,
## comments, lists and indented lines are ignored, so a frontmatter written
## for another tool still works. The line after the opening `---` must not
## be blank: `---` + blank line at the start of the file stays a slide
## separator.

import std/strutils

type Frontmatter* = object ## what the deck's frontmatter says
  title*, author*: string

proc isFence(line: string, closing = false): bool =
  let mark = line.strip(leading = false)
  mark == "---" or (closing and mark == "...")

proc unquote(value: string): string =
  ## `value` without one pair of matching `"` or `'` around it.
  if value.len >= 2 and value[0] in {'"', '\''} and value[^1] == value[0]:
    value[1 ..< ^1]
  else:
    value

proc splitFrontmatter*(src: string): tuple[meta: Frontmatter, body: string] =
  ## The frontmatter of `src` and the markdown after it. Without a
  ## frontmatter, an empty `meta` and `src` itself.
  result.body = src
  let lines = src.splitLines
  if lines.len < 2 or not lines[0].isFence or lines[1].isEmptyOrWhitespace:
    return
  for i in 1 ..< lines.len:
    if lines[i].isFence(closing = true):
      result.body = lines[i + 1 .. ^1].join("\n")
      return
    let line = lines[i]
    if line.len == 0 or line[0] in Whitespace:
      continue # nested values belong to some other key
    let colon = line.find(':')
    if colon < 0:
      continue
    let value = line[colon + 1 .. ^1].strip.unquote
    case line[0 ..< colon].strip
    of "title":
      result.meta.title = value
    of "author":
      result.meta.author = value
    else:
      discard
  result.meta = Frontmatter() # no closing fence: not a frontmatter
