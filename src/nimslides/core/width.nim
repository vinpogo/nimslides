## Terminal display width of text, by grapheme cluster.
##
## This mirrors celina's `runeWidth` and `clusterAt` (celina/core/buffer.nim,
## v0.17.0) so that what layout measures is exactly what the viewer paints.
## Core must not import celina, hence the copy; `tests/test_width.nim` checks
## that both agree. Update both together when upgrading celina.

import std/unicode
import pkg/unicodedb/[widths, properties, segmentation]

const
  zeroWidthCategories = ctgMn + ctgMe + ctgCf
  vs16 = 0xFE0F ## emoji presentation selector
  vs15 = 0xFE0E ## text presentation selector
  emojiModifierFirst = 0x1F3FB ## skin tones
  emojiModifierLast = 0x1F3FF
  keycap = 0x20E3 ## combining enclosing keycap

template isControlCode(n: int): bool =
  n < 0x20 or n == 0x7F or (n >= 0x80 and n <= 0x9F)

proc runeWidth*(r: Rune): int =
  ## Columns one code point takes on its own: 0 for combining marks and
  ## format controls, 2 for wide East Asian and emoji code points, else 1.
  let n = int(r)
  if n < 0x80 or n > 0x10FFFF:
    return 1
  if r.unicodeCategory in zeroWidthCategories:
    return 0
  case r.unicodeWidth
  of uwdtNarrow, uwdtHalf, uwdtAmbiguous, uwdtNeutral: 1
  else: 2

proc wordBreak(r: Rune): SgWord =
  if int(r) < 0 or int(r) > 0x10FFFF:
    sgwOther
  else:
    wordBreakProp(r)

proc clusterAt(runes: openArray[Rune], start: int): tuple[next, width: int] =
  ## The grapheme cluster starting at `start`: its exclusive end and width.
  let n = runes.len
  let lead = runes[start]
  var i = start + 1
  var w = runeWidth(lead)
  if isControlCode(int(lead)) or i >= n:
    return (i, w)
  let leadProp = wordBreak(lead)
  if leadProp == sgwRegionalIndicator and wordBreak(runes[i]) == sgwRegionalIndicator:
    return (i + 1, 2) # a flag
  let isEmoji = leadProp == sgwExtendedPictographic
  var promote, isKeycap = false
  while i < n:
    let cp = int(runes[i])
    if cp == vs16:
      if isEmoji:
        promote = true
    elif cp == vs15:
      promote = false
    elif cp in emojiModifierFirst .. emojiModifierLast:
      if isEmoji:
        promote = true
    elif cp == keycap:
      let l = int(lead)
      if l == 0x23 or l == 0x2A or l in 0x30 .. 0x39:
        isKeycap = true
    else:
      let p = wordBreak(runes[i])
      if p == sgwZwj:
        if isEmoji and i + 1 < n and wordBreak(runes[i + 1]) == sgwExtendedPictographic:
          promote = true
          i += 2
          continue
      elif p notin {sgwExtend, sgwFormat}:
        break
    inc i
  if promote or isKeycap:
    w = 2
  (i, w)

iterator clusters*(s: string): tuple[text: string, width: int] =
  ## The grapheme clusters of `s` with their display widths. Wrapping never
  ## splits inside one.
  let runes = s.toRunes
  var i = 0
  while i < runes.len:
    let (next, w) = clusterAt(runes, i)
    var text = ""
    for j in i ..< next:
      text.add $runes[j]
    yield (text, w)
    i = next

proc displayWidth*(s: string): int =
  ## Columns `s` takes in the terminal.
  for ch in s:
    if ch >= '\x80':
      let runes = s.toRunes
      var i = 0
      while i < runes.len:
        let (next, w) = clusterAt(runes, i)
        result += w
        i = next
      return
  s.len
