## The markdown core that features plug into; see docs/architecture.md.
## Features import this module and nothing else of nimslides.

import std/tables
import ./core/[ast, blocks, inlines, layout, links, registry, types, width]
export ast, blocks, inlines, layout, links, registry, types, width

proc renderDocument*(
    src: string, width: int, theme = initTable[string, Style]()
): seq[Line] =
  ## `src` parsed and laid out at `width` columns, without the slide margin.
  let doc = newDocCtx()
  let blocks = parseDocument(src, doc)
  var ctx = newLayoutCtx(width, doc)
  ctx.theme = theme
  ctx.layoutBlocks(blocks)
