## HTML tag grammar shared by the html (blocks) and html_inline features:
## CommonMark's tag names, attributes, open tags and closing tags.
##
## The procs take a string and a start index and return the index after
## what they matched, or -1 (`tagNameEnd`: `i`) when nothing matches. They
## never look past a mismatch, so callers decide what an HTML construct is.

import std/strutils

const
  htmlSpace* = {' ', '\t', '\n'} ## whitespace inside tags, line endings included
  tagChars = Letters + Digits + {'-'}
  attrStart = Letters + {'_', ':'}
  attrChars = Letters + Digits + {'_', '.', ':', '-'}
  notUnquoted = htmlSpace + {'"', '\'', '=', '<', '>', '`'}

proc skip*(s: string, i: int, chars: set[char]): int =
  ## The index after the run of `chars` starting at `i`.
  result = i
  while result < s.len and s[result] in chars:
    inc result

proc tagNameEnd*(s: string, i: int): int =
  ## The index after the tag name starting at `i` (a letter, then letters,
  ## digits or `-`), or `i` if there is none.
  if i < s.len and s[i] in Letters:
    s.skip(i + 1, tagChars)
  else:
    i

proc attrValueEnd(s: string, i: int): int =
  ## The index after an attribute value starting at `i`, or -1.
  if i >= s.len:
    return -1
  if s[i] in {'"', '\''}:
    let close = s.find(s[i], i + 1)
    return (if close < 0: -1 else: close + 1)
  result = s.skip(i, AllChars - notUnquoted)
  if result == i:
    result = -1

proc openTagEnd*(s: string, start: int): int =
  ## The index after an open tag (`<name attr="v" />`) starting with `<` at
  ## `start`, or -1.
  if start >= s.len or s[start] != '<':
    return -1
  var i = s.tagNameEnd(start + 1)
  if i == start + 1:
    return -1
  while true:
    let ws = s.skip(i, htmlSpace)
    if ws > i and ws < s.len and s[ws] in attrStart: # attribute
      i = s.skip(ws, attrChars)
      let eq = s.skip(i, htmlSpace)
      if eq < s.len and s[eq] == '=':
        i = s.attrValueEnd(s.skip(eq + 1, htmlSpace))
        if i < 0:
          return -1
    else:
      i = ws
      break
  if i < s.len and s[i] == '/':
    inc i
  if i < s.len and s[i] == '>':
    i + 1
  else:
    -1

proc closingTagEnd*(s: string, start: int): int =
  ## The index after a closing tag (`</name >`) starting with `<` at
  ## `start`, or -1.
  if not s.continuesWith("</", start):
    return -1
  let name = s.tagNameEnd(start + 2)
  if name == start + 2:
    return -1
  let i = s.skip(name, htmlSpace)
  if i < s.len and s[i] == '>':
    i + 1
  else:
    -1

proc tagEnd*(s: string, start: int): int =
  ## The index after an open or closing tag starting with `<` at `start`,
  ## or -1.
  if s.continuesWith("</", start):
    s.closingTagEnd(start)
  else:
    s.openTagEnd(start)
