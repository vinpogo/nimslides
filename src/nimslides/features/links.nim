## Links: inline `[text](url "title")`, reference links (`[text][label]`,
## `[text][]`, `[text]`) and autolinks `<https://…>` / `<me@example.com>`.
##
## The bracket, destination and reference parsing lives in core
## (`core/links.nim`); this feature builds the nodes and draws them. A link
## shows its text, then ` (url)` unless the text already is the url. Titles
## are parsed but not shown.
##
## Nested links (simplification, see docs/architecture.md): the outer link
## wins, and links inside its text are drawn as plain link text.

import std/strutils
import ../core

type Link* = ref object of InlineNode
  url*: string
  title*: string
  children*: seq[InlineNode]
  nested*: bool ## inside another link's text: drawn as its text only

var linkDepth = 0 ## how many link texts are being parsed right now

method spans(node: Link, ctx: LayoutCtx, base: Style): seq[Span] =
  if node.nested: # the outer link already styles the text and shows its url
    return node.children.spans(ctx, base)
  result = node.children.spans(ctx, base.merge(ctx.style("links.text")))
  var text = ""
  for span in result:
    text.add span.text
  if node.url.len > 0 and node.url != text and node.url != "mailto:" & text:
    result.add Span(text: " ", style: base)
    result.add Span(
      text: "(" & node.url & ")", style: base.merge(ctx.style("links.url"))
    )

method plainText(node: Link, ctx: LayoutCtx): string =
  ## Only the link text, without the url.
  node.children.plainText(ctx)

proc parseText(p: InlineParser, text: string): seq[InlineNode] =
  ## The inlines of a link's text; links found in there come out `nested`.
  inc linkDepth
  try:
    result = p.parseInlines(text)
  finally:
    dec linkDepth

# Autolinks -----------------------------------------------------------------

const
  schemeChars = Letters + Digits + {'+', '.', '-'}
  emailLocalChars =
    Letters + Digits + {
      '.', '!', '#', '$', '%', '&', '\'', '*', '+', '/', '=', '?', '^', '_', '`', '{',
      '|', '}', '~', '-',
    }
  labelChars = Letters + Digits + {'-'}

proc isUri(s: string): bool =
  ## CommonMark absolute URI: scheme of 2-32 chars, `:`, then no spaces,
  ## controls or `<` (the caller already stopped at `>`).
  let colon = s.find(':')
  if colon notin 2 .. 32 or s[0] notin Letters:
    return false
  for c in s[0 ..< colon]:
    if c notin schemeChars:
      return false
  for c in s[colon + 1 .. ^1]:
    if c <= ' ' or c in {'<', '\x7f'}:
      return false
  true

proc isEmail(s: string): bool =
  ## CommonMark's (HTML5's) email address pattern.
  let at = s.find('@')
  if at < 1 or at == s.high:
    return false
  for c in s[0 ..< at]:
    if c notin emailLocalChars:
      return false
  for label in s[at + 1 .. ^1].split('.'):
    if label.len notin 1 .. 63 or label[0] == '-' or label[^1] == '-':
      return false
    for c in label:
      if c notin labelChars:
        return false
  true

registerInline InlineRule(
  name: "links.autolink",
  triggers: {'<'},
  priority: 20,
  parse: proc(p: InlineParser): InlineNode =
    let close = p.src.find({'>', '<', '\n'}, p.pos + 1)
    if close < 0 or p.src[close] != '>':
      return nil # maybe inline HTML
    let address = p.src[p.pos + 1 ..< close]
    let url =
      if address.isUri:
        address
      elif address.isEmail:
        "mailto:" & address
      else:
        return nil
    result = Link(url: url, children: @[newText(address)], nested: linkDepth > 0)
    p.pos = close + 1,
)

# Inline and reference links --------------------------------------------------

registerInline InlineRule(
  name: "links",
  triggers: {'['},
  priority: 50,
  parse: proc(p: InlineParser): InlineNode =
    let text = p.linkText()
    let target = p.parseLinkTail(text)
    if target.found: # otherwise core keeps `[` as text, so `[[a]]` finds `[a]`
      result = Link(
        url: target.url,
        title: target.title,
        nested: linkDepth > 0,
        children: p.parseText(text.text),
      )
      p.pos = target.stop
  ,
)

defaultStyle(
  "links.text", Style(underline: true, fg: Color(kind: ckIndexed, index: 75))
)
defaultStyle("links.url", Style(fg: Color(kind: ckIndexed, index: 243)))
