## Slide separators: a line of `---` with a blank line (or the start or end
## of the file) on both sides, at the document's top level, starts a new
## slide. This is the convention of Marp, Slidev and reveal-md.
##
## Everything else that looks similar keeps its markdown meaning:
## `text` + `---` on the next line is a setext heading, `- - -`, `***` and
## `___` are thematic breaks, and a `---` inside a code block, a block quote
## or a list item is just content.
##
## The whole file is parsed as one document, so link reference definitions
## work across slides.

import std/strutils
import ./[ast, blocks, registry, types]

type SlideBreak* = ref object of BlockNode ## where one slide ends

method layout(node: SlideBreak, ctx: LayoutCtx): seq[Line] =
  @[] # `splitSlides` removes them; nothing to show if one slips through

proc isSlideSeparator*(line: string): bool =
  ## A run of three or more `-`, after at most 3 spaces of indent and with
  ## nothing but spaces after it.
  if line.indentOf > 3:
    return false
  let mark = line.strip
  mark.len >= 3 and mark.allCharsInSet({'-'})

registerBlock BlockRule(
  name: "slide_break",
  priority: 35, # before thematic_break (40), which also takes `---`
  interruptsParagraph: false, # it needs a blank line before it anyway
  parse: proc(p: BlockParser): BlockNode =
    if not p.nested and p.line.isSlideSeparator and (p.pos == 0 or p.peek(-1).isBlank) and
        p.peek(1).isBlank:
      result = SlideBreak()
      p.advance
  ,
)

proc splitSlides*(blocks: seq[BlockNode]): seq[seq[BlockNode]] =
  ## `blocks` cut at each `SlideBreak`. A separator at the very start or end
  ## of the file adds no empty slide; two separators in a row do (a blank
  ## slide). A document always has at least one slide.
  result = @[newSeq[BlockNode]()]
  for b in blocks:
    if b of SlideBreak:
      result.add newSeq[BlockNode]()
    else:
      result[^1].add b
  if result.len > 1 and result[0].len == 0:
    result.delete 0
  if result.len > 1 and result[^1].len == 0:
    result.setLen result.len - 1
