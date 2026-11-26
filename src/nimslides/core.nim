## The markdown core that features plug into; see docs/architecture.md.
## Features import this module and nothing else of nimslides.

import std/tables
import
  ./core/[
    ast, blocks, frontmatter, html, inlines, layout, links, registry, slides, types,
    width,
  ]
export
  ast, blocks, frontmatter, html, inlines, layout, links, registry, slides, types, width

proc renderDocument*(
    src: string, width: int, theme = initTable[string, Style]()
): seq[Line] =
  ## `src` parsed and laid out at `width` columns, without the slide margin.
  ## A frontmatter is left out.
  let doc = newDocCtx()
  let blocks = parseDocument(src.splitFrontmatter.body, doc)
  var ctx = newLayoutCtx(width, doc)
  ctx.theme = theme
  ctx.layoutBlocks(blocks)

proc renderSlides*(
    src: string, width: int, theme = initTable[string, Style]()
): seq[seq[Line]] =
  ## Like `renderDocument`, but one list of lines per slide; slides are
  ## separated by `---` lines (see `core/slides.nim`). A frontmatter is left
  ## out (see `core/frontmatter.nim`).
  let doc = newDocCtx()
  var ctx = newLayoutCtx(width, doc)
  ctx.theme = theme
  for slide in parseDocument(src.splitFrontmatter.body, doc).splitSlides:
    result.add ctx.layoutBlocks(slide)
