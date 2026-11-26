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

proc after(s: string, i: int, terminator: string): int =
  ## The index after the first `terminator` at or after `i`, or -1.
  let at = s.find(terminator, i)
  if at < 0:
    -1
  else:
    at + terminator.len

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
    (s.closingTagEnd(start), false)
  else:
    (s.openTagEnd(start), false)

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
      if start == 0 or p.src[start - 1] in htmlSpace:
        # Hidden HTML leaves no gap: `a <br/> b` reads "a b".
        p.pos = p.src.skip(stop, htmlSpace)
  ,
)
