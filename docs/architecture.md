# nimslides architecture

How markdown becomes a slide, and how to add one markdown feature without
touching anything else.

## Pipeline

```mermaid
flowchart LR
  src[markdown source] --> bp[block parser<br>core/blocks.nim]
  bp -->|block rules, paragraph + hooks| tree[BlockNode tree<br>+ DocCtx]
  tree --> lay[layout<br>core/layout.nim]
  lay -->|"Paragraph etc.: ctx.inlines(raw)"| ip[inline parser<br>core/inlines.nim]
  ip -->|InlineNodes| lay
  lay --> lines["seq[Line] of styled Spans"]
  lines --> rs[renderSlides<br>render.nim: adds margin]
  rs --> viewer[viewer.nim<br>paints with celina]
  rs --> pipe[nimslides.nim<br>prints plain text when piped]
```

0. **Frontmatter.** `core/frontmatter.nim` cuts a leading `---` … `---`
   block off the source; its `title` and `author` go in the viewer's footer.
1. **Blocks.** The source is split into lines (tabs expanded to 4-column
   stops). At each non-blank line, block rules are tried in priority order;
   if none matches, core's **paragraph** takes the line plus following lines.
2. **Inlines are parsed during layout**, not during block parsing, so
   document state collected anywhere in the document (e.g. link reference
   definitions) is complete by then.
3. **Slides.** Core's `slide_break` rule turns a top-level `---` between
   blank lines into a `SlideBreak` node; `splitSlides` cuts the block list
   there. The whole file is one document, so references work across slides.
4. **Layout** turns each block into lines at a given width; blocks are
   separated by one blank line. Inline nodes produce spans; `wrap` breaks
   them into lines.

## Modules

| Module | Responsibility |
|---|---|
| `core/types.nim` | `Color`, `Style`, `Span`, `Line`, `Slide`, `plain`, `merge`, `indexed` |
| `core/width.nim` | display width and grapheme clusters; a copy of celina's logic, checked against celina in `tests/test_layout.nim` |
| `core/ast.nim` | open node types `BlockNode`, `InlineNode` with base methods; core's `Paragraph` and `Text`; `DocCtx`, `LayoutCtx` |
| `core/registry.nim` | rule types, `register*` procs, `defaultStyle`, `ctx.style(key)` |
| `core/blocks.nim` | `BlockParser` cursor, paragraph fallback with hooks, `parseBlocks`, container helpers (`isLazy`, `claimedBefore`, `scratchBlocks`) |
| `core/inlines.nim` | text, backslash escapes, soft breaks, rule dispatch, delimiter-run matching |
| `core/layout.nim` | `wrap`, `ctx.inlines`, `layoutBlocks`, `ctx.renderBlocks`, `ctx.literalRows`, `line.fit`, paragraph layout |
| `core/links.nim` | link text, inline destination/title and reference parsing shared by links and images; registers the reference definition hook |
| `core/slides.nim` | the `slide_break` rule (`---` between blank lines, top level only), `splitSlides` |
| `core/frontmatter.nim` | `splitFrontmatter`: a leading `---` block of `key: value` lines (only `title`, `author` are read); the line after the opening `---` must not be blank, so `---` + blank line stays a slide separator |
| `core/html.nim` | HTML tag grammar (tag names, attributes, open and closing tags) shared by `html` and `html_inline` |
| `core/discover.nim` | `importAll(dir)`: compile-time import of every `.nim` file in a folder |
| `core.nim` | re-exports core; `renderDocument(src, width)`, `renderSlides(src, width)`. **Features import only this.** |
| `features.nim` | `importAll("features")`; nothing to edit when adding a feature |
| `features/<name>.nim` | one markdown feature each |
| `render.nim` | `renderSlides` = core's `renderSlides` + `margin` + the `slide` style; `Theme`, `themed`; re-exports `core/types` |
| `theme.nim` | theme files: `parseTheme`, `loadTheme`, `parseColor`, `formatTheme`, `defaultTheme` |
| `viewer.nim` | the only module that imports celina |

Rules: features never import each other, never import celina, and never
import anything of nimslides but `../core`.

`code_fenced` highlights code by running `bat` (`std/osproc`), an optional
runtime dependency: without it, or when it fails or changes the text, the
card stays plain. Results are cached per command, language and code, since
the viewer lays slides out again on every resize. Tests set
`highlighter` to `tests/fixtures/fake_bat.sh` or a missing command.

## One feature = three files

A feature task creates or changes only:

- `src/nimslides/features/<name>.nim`
- `tests/features/test_<name>.nim`
- `examples/features/<name>.md`

Nothing else: no list to register in, no core edits. If a feature seems to
need a core change (a new hook, a helper several features share, a change to
paragraphs or wrapping), stop and ask for it as a **separate core task**.
Core changes are done one at a time, never in parallel with each other.

## Feature file template

The file name is the feature name (a valid Nim identifier, e.g.
`thematic_break.nim`). Example with made-up syntax:

```nim
## Notes: a line starting with "NOTE:" shown dimmed, and @mentions in bold.

import std/strutils
import ../core

type
  Note* = ref object of BlockNode # export node types so tests can inspect them
    raw*: string
  Mention* = ref object of InlineNode
    name*: string

method layout(node: Note, ctx: LayoutCtx): seq[Line] =
  wrap(ctx.inlines(node.raw, ctx.style("note")), ctx.width)

method spans(node: Mention, ctx: LayoutCtx, base: Style): seq[Span] =
  @[Span(text: "@" & node.name, style: base.merge(ctx.style("note.mention")))]

registerBlock BlockRule(
  name: "note",
  priority: 95,
  interruptsParagraph: false,
  parse: proc(p: BlockParser): BlockNode =
    if p.line.startsWith("NOTE:"): # nil = no match; core restores p.pos
      result = Note(raw: p.line[5 .. ^1].strip)
      p.advance,
)

registerInline InlineRule(
  name: "mention",
  triggers: {'@'},
  priority: 95,
  parse: proc(p: InlineParser): InlineNode =
    var i = p.pos + 1
    while i < p.src.len and p.src[i] in IdentChars:
      inc i
    if i > p.pos + 1:
      result = Mention(name: p.src[p.pos + 1 ..< i])
      p.pos = i,
)

defaultStyle("note", Style(dim: true))
defaultStyle("note.mention", Style(bold: true))
```

What a feature file must contain:

- `import ../core` (plus `std/` modules it needs). Nothing else is required:
  no `{.used.}`, no export list. `features.nim` silences "imported and not
  used" for the feature modules themselves.
- Node types inheriting `BlockNode` / `InlineNode`, each overriding exactly
  one of these, at top level (a missing override raises at runtime):
  - `method layout(node: X, ctx: LayoutCtx): seq[Line]` — lines at most
    `ctx.width` columns wide
  - `method spans(node: X, ctx: LayoutCtx, base: Style): seq[Span]` —
    `base` is the style of the enclosing nodes; `merge` your style on top.
    A span may contain `"\n"` to force a line break (hard line breaks).
- `register*` calls and `defaultStyle` calls at module top level.

### Core API

```nim
# blocks (core/registry.nim, core/blocks.nim)
registerBlock(BlockRule(name, priority, interruptsParagraph, parse: proc(p: BlockParser): BlockNode))
registerParagraphCloser(ParagraphCloser(name, priority, close: proc(p: BlockParser): ParagraphBuild))
registerParagraphStart(ParagraphStart(name, priority, consume: proc(lines: seq[string], doc: DocCtx): int))
type ParagraphBuild = proc(lines: seq[string]): BlockNode
p.line; p.peek(offset); p.advance(n); p.eof; p.pos; p.lines; p.doc
p.takeWhile(pred); p.interrupting; p.interruptsParagraph()
p.parseBlocks(lines)        # containers: parse inner lines, shares doc
p.claimedBefore(priority)   # does a rule that runs before `priority` start here? (`* * *` vs a list)
p.isLazy(inner); lazyLine(line)  # containers: lazy continuation lines, see below
scratchBlocks(lines)        # parse with throwaway doc state, to inspect structure only
method endsInParagraph(node: MyContainer): bool  # containers: ask the last child
isBlank(line); indentOf(line); expandTabs(line)

# inlines (core/registry.nim, core/inlines.nim)
registerInline(InlineRule(name, triggers: set[char], priority, parse: proc(p: InlineParser): InlineNode))
registerDelimiter(DelimiterRule(name, ch, intraword, ruleOf3, sameLength, maxRun,
                                build: proc(count: int, children: seq[InlineNode]): InlineNode))
p.src; p.pos; p.peek(offset): char; p.doc; p.parseInlines(text)  # nested content, e.g. link labels
asciiPunctuation

# layout (core/layout.nim, core/ast.nim)
ctx.width; ctx.depth; ctx.doc; ctx.style(key)
ctx.inlines(raw, base): seq[Span]
wrap(spans, width): seq[Line]
ctx.renderBlocks(children, width, gap = 1): seq[Line]   # containers
ctx.literalRows(lines, style, lead): seq[Line]  # code-like text: hard-wrapped, padded to ctx.width
ctx.literalRows(lines: seq[Line], style, lead)  # the same for styled lines (e.g. highlighted code), spans drawn over `style`
ctx.filledRow(style): Line                      # an empty full-width row, e.g. a card's edge
nodes.spans(ctx, base)                                   # children of an inline node
node.plainText(ctx); nodes.plainText(ctx)  # text without styles, e.g. image alt text
doc.state("<feature>", MyState)   # per-feature document state, MyState = ref object of RootObj
Text(text: "...")                 # core's literal text node
newText("...")                    # the same, typed InlineNode: @[newText("a")]

# width (core/width.nim, core/layout.nim): always measure in columns, never bytes
displayWidth(s); line.displayWidth  # terminal columns of a string or a Line
for (text, width) in s.clusters     # grapheme clusters; never split one
fit(s, width): (text, width)        # the leading clusters that fit
line.fit(width): Line               # the same for a styled Line
hardWrap(s, width): seq[(text, width)]  # literal text cut into rows, spaces kept (code, tables)
line.hardWrap(width): seq[(line, width)]  # the same for a styled Line

# styles (core/types.nim)
Style(bold, italic, underline, dim, strikethrough, fg, bg); base.merge(over); line.plain
indexed(205)                        # a 256-palette Color: Style(fg: indexed(205))

# html tags (core/html.nim); like links, these take (s, start) and return the index after the match, or -1
s.openTagEnd(start); s.closingTagEnd(start); s.tagEnd(start)  # at `<`
s.tagNameEnd(i)                     # `i` if no tag name starts there
s.skip(i, chars); htmlSpace         # whitespace inside tags includes "\n"

# links and images (core/links.nim); these never move p.pos, they return `stop`
type LinkText = object            # found, text (raw, between the brackets), start, stop (after `]`)
type LinkTarget = object          # found, url, title (escapes resolved), stop (after the tail)
p.linkText(): LinkText            # at `[`; linkText(p.src, p.pos + 1) for an image's `![`
p.parseLinkTail(text): LinkTarget # `(dest "title")`, else [label], [] or shortcut reference
linkText(src, start); linkLabel(src, start); inlineTarget(src, start)  # the parts
p.referenceTarget(text)           # reference forms only
doc.lookupReference(label); doc.defineReference(label, url, title): bool
normalizeLabel(label); resolveEscapes(s); parseDefinition(src)
```

Contract details:

- **Rule procs** return `nil` for "no match"; core restores the cursor. On a
  match they must advance past what they took.
- **Block rules** are called on non-blank lines. When core checks whether a
  line interrupts a paragraph it calls the rules with
  `interruptsParagraph = true` with `p.interrupting = true` and discards the
  result; such calls must not change `p.doc`. Use the flag for conditional
  interruption (an ordered list must start at 1, an empty list item cannot
  interrupt, only some HTML blocks can).
- **Paragraph closer** (setext headings): checked on every line after a
  paragraph's first, *before* the interruption check. Return a builder and
  advance past the underline. Builders receive the paragraph's lines with
  leading whitespace stripped, after start hooks ran. A closer must ignore
  lines indented 4 or more spaces, as every setext underline does: that is
  how `lazyLine` keeps lazy lines from closing a paragraph.
- **Containers** (block quotes, lists) parse their content with
  `p.parseBlocks(inner)`. While `p.interrupting`, only check the marker,
  advance and return an empty node; never parse content then. A line without
  the container's marker continues it lazily when `p.isLazy(inner)`; add it
  as `lazyLine(p.line)`. Override `endsInParagraph` to return
  `children.endsInParagraph`, so lazy lines also reach paragraphs nested in
  other containers. Look at content structure only via `scratchBlocks`, never
  by reading `registered` directly.
- **Paragraph start hook** (core's own link reference definitions, prio 10): runs on a finished
  paragraph's lines, returns how many leading lines it consumed and stores
  what it found with `doc.state(...)`. If nothing is left, the paragraph
  disappears, and a closer's line is parsed again (`[a]: /u` + `===` gives
  a paragraph `===`, as in CommonMark).
- **Delimiters**: core does all of CommonMark's delimiter-run work (left/right
  flanking, `_` intraword rules via `intraword = false`, rule of 3 via
  `ruleOf3`, nesting). The feature only builds the node: `count` is how many
  delimiters were matched (1 or 2 for `*`/`_`; with `sameLength` the whole
  run). For GFM strikethrough use `ch: '~', intraword: true,
  sameLength: true, maxRun: 2`. One rule per character.
- **Escapes**: core turns `\` + ASCII punctuation into literal text, unless
  an inline rule on `\` matched first (hard line break `\` + newline).
  Soft line breaks become one space; trailing spaces before them are
  dropped, so a hard-break rule must trigger on `' '` and match `"  \n"`.
- **Runs of a trigger character**: core only skips one character after a
  rule returns nil, then tries again at the next one. A rule that scans a
  run (backticks, spaces) and doesn't match must return the whole run as
  `newText(run)` and advance past it, or core retries mid-run (```` ```foo`` ````
  would then become a code span). Exception: don't return text right before
  a `"\n"`, since core's soft break can only drop spaces it still sees
  (see `hard_break.nim`).
- **`plainText`** defaults to the node's spans with line breaks as spaces.
  Override it when `spans` shows more than the content, as links do for
  their url.
- **Tabs** are expanded to spaces (stops of 4) before block parsing, so code
  never contains literal tabs.
- Code spans, autolinks and HTML take their text before delimiters see it:
  inline rules run at their trigger before core's delimiter scanning.

## Priorities

Smaller numbers run first; ties are broken by rule name, so import order
never matters. Delimiter rules have no priority: inline rules on the same
character run before delimiter scanning.

### Blocks (`registerBlock`)

| Prio | Feature (file) | Interrupts a paragraph |
|---:|---|---|
| 10 | indented code (`code_indented`) | no |
| 20 | fenced code (`code_fenced`) | yes |
| 30 | ATX heading (`heading`) | yes |
| 35 | slide separator (`slide_break`, core) | no; needs a blank line on both sides and `p.nested == false` |
| 40 | thematic break (`thematic_break`) | yes |
| 50 | blockquote (`blockquote`) | yes |
| 60 | list: bullet, ordered, task (`list`) | yes, conditionally (`p.interrupting`): not an empty item, ordered only from 1 |
| 70 | HTML block / comment (`html`) | yes for comments and known tags (CommonMark types 1-6), not type 7 |
| 80 | table (`table`) | no |
| — | paragraph | core fallback |

Paragraph hooks:

| Prio | Hook | Feature |
|---:|---|---|
| 10 | closer: setext heading (`===` / `---` under a paragraph) | `heading` |
| 10 | start: link reference definitions, stored in `doc.references` | core (`core/links.nim`) |

The `-` conflicts are resolved by this order: under a paragraph line, `---`
is a **setext heading** (closers run before interruption checks); elsewhere
`---`, `***`, `- - -` are a **thematic break** (40) before a **list item**
(60) is tried; `- item` is a list. A top-level `---` with a blank line (or
the start or end of the file) on both sides is the **slide separator**
(35), so the thematic break only sees `---` that touches text or sits in a
container. Containers parse their content with `parseBlocks(p, lines)`,
which sets `p.nested`; a scratch `newBlockParser` does not.

### Inlines

| Prio | Feature (file) | Mechanism | Triggers |
|---:|---|---|---|
| 10 | code span (`code_span`) | `registerInline` | `` ` `` |
| 20 | autolink (`links`) | `registerInline` | `<` |
| 30 | inline HTML (`html_inline`) | `registerInline` | `<` |
| 40 | image (`image`) | `registerInline` | `!` |
| 50 | link: inline, reference (`links`) | `registerInline` | `[` |
| 60 | hard line break (`hard_break`) | `registerInline` | `' '`, `\` |
| — | emphasis / strong (`emphasis`) | `registerDelimiter` | `*`, `_` |
| — | strikethrough (`strikethrough`) | `registerDelimiter` | `~` |

### Links and images

Links and images share their parsing, which lives in `core/links.nim`, so
the two features are independent and stay small. Core also registers the
paragraph-start hook for reference definitions (`[label]: dest "title"`,
title optionally on the next line); a paragraph made only of definitions
disappears. Definitions are stored per document, first definition wins,
labels are compared case-folded with whitespace collapsed. Neither feature
registers a paragraph hook.

A rule for `[` (links) or `!` (images) does:

```nim
parse: proc(p: InlineParser): InlineNode =
  let text = p.linkText()                # image: linkText(p.src, p.pos + 1)
  let target = p.parseLinkTail(text)     # not found if `text` was not found
  if target.found:
    result = Link(url: target.url, title: target.title,
                  children: p.parseInlines(text.text))
    p.pos = target.stop
```

An image is `!` followed by exactly the same text and tail; its children
are the alt text (render them as plain text). If no tail matches, return
nil: core keeps the `[` (or `!`) as text and goes on with the next
character, so `[[foo]]` can still find the inner `[foo]`.

**Nested links (simplification).** CommonMark forbids links inside link
text: in `[a [b](/x)](/y)` the inner link wins and the outer brackets stay
text. nimslides does not enforce this: the outer link matches first, and
its text is parsed with `p.parseInlines`, which may produce an inner link.
The links feature keeps it simple by unwrapping such inner links when it
builds the outer one (replace an inner `Link` in `children` by its own
children), so they show as plain link text; images inside links (`[![alt](i.png)](/u)`) are fine either
way. Other known gaps of the core helpers: no HTML entities in destinations
and titles, labels are lowercased instead of fully Unicode case-folded, and
autolinks / raw HTML inside link text don't take precedence over `]`.

## Style keys

`defaultStyle("<feature>", style)` or `defaultStyle("<feature>.<element>",
style)`. `<feature>` is exactly the file name, which is also the rule name
(plus `.<suffix>` for a feature's further rules, e.g. `links.autolink`).
That is what keeps parallel features from ever claiming the same key, so
don't shorten or regroup it: `code_fenced`, not `code.block`. Emphasis is the
one exception, with `emphasis` and `strong`.

The full list, with defaults, is `themes/default.ini` (a test keeps it in
sync with the registry; regenerate it with `nimslides --print-theme >
themes/default.ini` after adding or changing a `defaultStyle`). Core owns
`paragraph`; `render.nim` owns `slide`, `footer`, `footer.counter`, `footer.author` and
`footer.title`. Look styles up
with `ctx.style(key)`: a theme override, else the default, else plain.
Never hardcode a color or attribute in a feature: anything without a key
can't be themed.
Registering a key twice fails at startup.

## Themes

`nimslides --theme FILE` restyles any style key. A theme is an INI file
(`theme.nim`; no parser library, so error messages have exact line numbers):

```ini
# comments start with # or ; at the start of a line or after whitespace
[slide]            # the base style of every slide; its bg fills the screen
fg = 236
bg = 255

[heading.1]
fg = #ff5fd7       # only fg changes, bold stays on from the default

[strong]
bold = false       # switch an attribute off
```

- A section is a style key; unknown keys, attributes or values are errors
  (`file:line: message`), so typos don't pass silently.
- Attributes: `fg`, `bg`; `bold`, `italic`, `underline`, `dim`,
  `strikethrough` (`true` / `false`).
- Colors: `default` (the terminal's), `0`-`255` (palette), `#rrggbb`
  (quotes optional), `black red green yellow blue magenta cyan white` and
  `bright_<name>` (palette 0-15).
- **Patching**: a section changes only the attributes it names.
  `parseTheme` starts from the registered default, so the result is a full
  `Table[string, Style]` and `ctx.style` needs no patch logic. Themes are
  parsed after all features registered, i.e. at runtime in `main`.
- **`slide`**: `render.renderSlides` merges every span over the `slide`
  style (`slide.style.merge(span.style)`), margin included, and stores it
  in `Slide.style`; the viewer clears the screen with it first. A span's
  own colors win, so code blocks keep their bg.
- **`footer`**: a deck's bottom row, filled edge to edge (over `slide`),
  e.g. a status bar color; `footer.counter` is the slide number on it
  (over `footer`). A single slide has no footer.
- `nimslides --print-theme` writes every key with every attribute
  (`themes/default.ini`); `examples/themes/light.ini` is an example theme.

## Testing a feature

`tests/features/test_<name>.nim`:

```nim
import std/unittest
import ../helpers
import nimslides/features/note # only this feature is registered

suite "note":
  test "renders dimmed":
    check render("NOTE: hi") == @["hi"]
    check styleOf("NOTE: hi", "hi") == Style(dim: true)
    check parse("NOTE: hi")[0] of Note

  test "the example renders":
    check render(example("note"), 40).len > 0
```

`tests/helpers.nim` imports core only, so a feature test runs with just its
own feature (import others explicitly to test interplay):

- `render(md, width = 40): seq[string]` — plain lines, no slide margin,
  `""` between blocks
- `styled(md, width = 40): seq[Line]` — the same with styles
- `styleOf(md, text): Style` — style of the first span containing `text`
- `parse(md): seq[BlockNode]`, `parseInline(raw): seq[InlineNode]` — nodes to
  inspect with `of` and conversions
- `widths(md, width = 40): seq[int]` — display width of each row, for
  `check widths(md, w).allIt(it <= w)` (import `std/sequtils`)
- `example(name)` — contents of `examples/features/<name>.md`

Importing another feature into a feature test registers it for every test
in that file. Tests of features working together go in
`tests/test_together.nim` instead, which imports all features.

`examples/features/<name>.md` shows every case of the feature; `examples/showcase.md`
uses all features together. Check by eye with
`COLUMNS=60 ./nimslides examples/features/<name>.md` and in the viewer.

Run everything with `nimble test` (runs `tests/test_*.nim` and
`tests/features/test_*.nim`). Core tests that register test-only rules use
`let empty = snapshot()` and `restore empty` in `setup`.

## Dependencies and Nix

Prefer no new dependencies. If one is needed: add it to `nimslides.nimble`,
then regenerate the lock **inside the dev shell**:
`nix develop -c nim_lk > lock.json`. Never `nix run nixpkgs#nim_lk`: it is
unpatched and locks wrong revisions of `v`-prefixed tags. The Nix source is
`nimslides.nimble` plus every `.nim` under `src/`; new files must be added to
git (`git add`) before `nix build` sees them.

## Interactive regions (planned, not built)

- `Slide` gains `regions: seq[Region]`; a region has the rows it covers, a
  kind (e.g. `collapsible`) and state (e.g. `expanded`), plus an id stable
  across re-renders.
- Features describe what is interactive, never how it is drawn: e.g. a
  fenced code block's layout reports "rows 3-12, collapsible, collapsed
  shows 3 rows". `LayoutCtx` will carry the state per region id so layout
  produces the collapsed or expanded lines, and a way to report regions
  (row offsets are fixed up as containers stack their children).
- `viewer.nim` maps regions to celina widgets/key handling (focus, toggle),
  updates the state and re-renders the slide.
- Markdown features never import celina; this needs a core task (types,
  context, layout bookkeeping) before any feature uses it.
