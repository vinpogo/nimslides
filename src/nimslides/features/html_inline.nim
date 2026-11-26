## Raw inline HTML (CommonMark): open and closing tags with attributes,
## comments, processing instructions, declarations and CDATA sections.
##
## Terminals can't render HTML, so all of it is hidden and the text between
## tags renders normally: `<kbd>x</kbd>` shows `x`. HTML with whitespace
## before it also takes the whitespace after it, so `a <br/> b` reads "a b"
## without a double space. Anything that isn't valid raw HTML is no match,
## so its `<` stays text. The autolink rule (`links`, priority 20) runs
## first on `<`.

import std/strutils
import ../core

type HtmlInline* = ref object of InlineNode
  raw*: string ## the HTML exactly as written
  comment*: bool ## an HTML comment rather than a tag or other construct

method spans(node: HtmlInline, ctx: LayoutCtx, base: Style): seq[Span] =
  discard # hidden: terminals can't render HTML

const
  Space = {' ', '\t', '\n'}
  TagChars = Letters + Digits + {'-'}
  AttrStart = Letters + {'_', ':'}
  AttrChars = Letters + Digits + {'_', '.', ':', '-'}
  NotUnquoted = Space + {'"', '\'', '=', '<', '>', '`'}

proc skip(s: string, i: int, chars: set[char]): int =
  ## The index after the run of `chars` starting at `i`.
  result = i
  while result < s.len and s[result] in chars:
    inc result

proc after(s: string, i: int, terminator: string): int =
  ## The index after the first `terminator` at or after `i`, or -1.
  let at = s.find(terminator, i)
  if at < 0:
    -1
  else:
    at + terminator.len

proc attrValue(s: string, i: int): int =
  ## The index after an attribute value starting at `i`, or -1.
  if i >= s.len:
    return -1
  if s[i] in {'"', '\''}:
    let close = s.find(s[i], i + 1)
    return (if close < 0: -1 else: close + 1)
  result = s.skip(i, AllChars - NotUnquoted)
  if result == i:
    result = -1

proc openTag(s: string, start: int): int =
  ## The index after an open tag starting with `<` at `start`, or -1.
  var i = start + 1
  if i >= s.len or s[i] notin Letters:
    return -1
  i = s.skip(i, TagChars)
  while true:
    let ws = s.skip(i, Space)
    if ws > i and ws < s.len and s[ws] in AttrStart: # attribute
      i = s.skip(ws, AttrChars)
      let eq = s.skip(i, Space)
      if eq < s.len and s[eq] == '=':
        i = s.attrValue(s.skip(eq + 1, Space))
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

proc closingTag(s: string, start: int): int =
  ## The index after a closing tag starting with `</` at `start`, or -1.
  var i = start + 2
  if i >= s.len or s[i] notin Letters:
    return -1
  i = s.skip(s.skip(i, TagChars), Space)
  if i < s.len and s[i] == '>':
    i + 1
  else:
    -1

proc htmlEnd(s: string, start: int): (int, bool) =
  ## The index after the raw HTML starting with `<` at `start` (-1 if there
  ## is none), and whether it is a comment.
  template at(prefix: string): bool =
    s.continuesWith(prefix, start)

  if at("<!-->"):
    (start + 5, true)
  elif at("<!--->"):
    (start + 6, true)
  elif at("<!--"):
    (s.after(start + 4, "-->"), true)
  elif at("<?"):
    (s.after(start + 2, "?>"), false)
  elif at("<![CDATA["):
    (s.after(start + 9, "]]>"), false)
  elif at("<!") and start + 2 < s.len and s[start + 2] in Letters:
    (s.after(start + 3, ">"), false)
  elif at("</"):
    (s.closingTag(start), false)
  else:
    (s.openTag(start), false)

registerInline InlineRule(
  name: "html_inline",
  triggers: {'<'},
  priority: 30,
  parse: proc(p: InlineParser): InlineNode =
    let start = p.pos
    let (stop, comment) = p.src.htmlEnd(start)
    if stop > 0:
      result = HtmlInline(raw: p.src[start ..< stop], comment: comment)
      p.pos = stop
      if start == 0 or p.src[start - 1] in Space:
        # Hidden HTML leaves no gap: `a <br/> b` reads "a b".
        p.pos = p.src.skip(stop, Space)
  ,
)
