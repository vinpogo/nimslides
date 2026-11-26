## Where features plug in. Every feature calls the `register*` procs below
## at its module's top level.
##
## Rules run in ascending `priority` (smaller first), ties broken by name, so
## the order never depends on import order. Names must be unique.

import std/[algorithm, tables]
import ./[ast, types]

type
  BlockParser* = ref object
    ## A cursor over the lines of a document or of a container's content.
    ## See `blocks.nim` for the procs that move it.
    lines*: seq[string] ## tab-expanded lines
    pos*: int ## the current line
    doc*: DocCtx
    interrupting*: bool
      ## true while core asks whether the current line interrupts a
      ## paragraph; rules that may only interrupt in some cases (e.g. an
      ## ordered list starting at 1) check it

  BlockParse* = proc(p: BlockParser): BlockNode
    ## Called with `p.pos` on a non-blank line. Returns nil if the rule does
    ## not start here (core then restores `p.pos`), otherwise advances past
    ## the lines it took and returns the node.

  BlockRule* = object
    name*: string
    priority*: int
    interruptsParagraph*: bool
      ## whether this block may start right after a paragraph line, ending
      ## the paragraph (CommonMark "can interrupt a paragraph")
    parse*: BlockParse

  ParagraphBuild* = proc(lines: seq[string]): BlockNode
    ## Builds the block that replaces a paragraph from its lines.

  ParagraphCloser* = object
    ## Checked on each line after the first of a paragraph, before the
    ## interruption check. `close` returns nil, or advances past the lines it
    ## takes (e.g. a setext underline) and returns how to build the block that
    ## replaces the paragraph. If paragraph-start hooks then leave no lines,
    ## core rewinds to the closing line and parses it afresh.
    name*: string
    priority*: int
    close*: proc(p: BlockParser): ParagraphBuild

  ParagraphStart* = object
    ## Run on a finished paragraph's lines before it is built. `consume`
    ## returns how many leading lines it took (e.g. link reference
    ## definitions, stored in `doc`), 0 for none. Hooks run until none takes
    ## more; a paragraph left with no lines disappears.
    name*: string
    priority*: int
    consume*: proc(lines: seq[string], doc: DocCtx): int

  InlineParser* = ref object
    ## A cursor over the raw text of one inline container (e.g. a paragraph).
    src*: string
    pos*: int
    doc*: DocCtx

  InlineRule* = object
    name*: string
    triggers*: set[char] ## characters at which `parse` is tried
    priority*: int
    parse*: proc(p: InlineParser): InlineNode
      ## Called with `p.pos` on a trigger character. Returns nil if nothing
      ## starts here (core restores `p.pos`), otherwise advances past what it
      ## took and returns the node.

  DelimiterRule* = object
    ## Emphasis-style runs of `ch`, matched by the CommonMark delimiter
    ## algorithm in `inlines.nim`. The feature only builds the node.
    name*: string
    ch*: char
    intraword*: bool
      ## true for `*` and `~`: runs inside a word may open and close. false
      ## for `_`, which follows CommonMark's stricter underscore rules
    ruleOf3*: bool ## apply CommonMark's "multiple of 3" rule (`*`, `_`)
    sameLength*: bool
      ## opener and closer must be runs of equal length, and the whole run is
      ## used (GFM `~`); otherwise 2 delimiters are used when both runs have
      ## at least 2, else 1 (`*`, `_`)
    maxRun*: int ## longer runs stay literal; 0 for no limit
    build*: proc(count: int, children: seq[InlineNode]): InlineNode
      ## the node for `count` matched delimiters around `children`

  Registry* = object ## all registered rules; see `snapshot`
    blockRules*: seq[BlockRule]
    closers*: seq[ParagraphCloser]
    starts*: seq[ParagraphStart]
    inlineRules*: seq[InlineRule]
    delimiters*: seq[DelimiterRule]
    styles*: Table[string, Style]

var registered*: Registry
  ## all rules, read by the parsers; change it only via `register*`

proc byOrder[T](a, b: T): int =
  result = cmp(a.priority, b.priority)
  if result == 0:
    result = cmp(a.name, b.name)

proc insert[T](rules: var seq[T], rule: T) =
  for r in rules:
    doAssert r.name != rule.name, "rule registered twice: " & rule.name
  rules.add rule
  rules.sort(byOrder[T])

proc registerBlock*(rule: BlockRule) =
  doAssert rule.parse != nil, rule.name & ": no parse proc"
  registered.blockRules.insert rule

proc registerParagraphCloser*(hook: ParagraphCloser) =
  doAssert hook.close != nil, hook.name & ": no close proc"
  registered.closers.insert hook

proc registerParagraphStart*(hook: ParagraphStart) =
  doAssert hook.consume != nil, hook.name & ": no consume proc"
  registered.starts.insert hook

proc registerInline*(rule: InlineRule) =
  doAssert rule.parse != nil, rule.name & ": no parse proc"
  doAssert rule.triggers != {}, rule.name & ": no trigger characters"
  registered.inlineRules.insert rule

proc registerDelimiter*(rule: DelimiterRule) =
  doAssert rule.build != nil, rule.name & ": no build proc"
  for r in registered.delimiters:
    doAssert r.name != rule.name, "rule registered twice: " & rule.name
    doAssert r.ch != rule.ch, "delimiter '" & rule.ch & "' registered twice"
  registered.delimiters.add rule
  registered.delimiters.sort(
    proc(a, b: DelimiterRule): int =
      cmp(a.name, b.name)
  )

proc defaultStyle*(key: string, style: Style) =
  ## Registers the default style for `key`, named "<feature>.<element>" or
  ## just "<feature>" (see docs/architecture.md).
  doAssert key notin registered.styles, "style registered twice: " & key
  registered.styles[key] = style

proc style*(ctx: LayoutCtx, key: string): Style =
  ## The style for `key`: the theme's, else the registered default, else
  ## plain.
  if key in ctx.theme:
    ctx.theme[key]
  else:
    registered.styles.getOrDefault(key)

proc delimiterFor*(ch: char): int =
  ## Index of the delimiter rule for `ch` in `registered.delimiters`, or -1.
  for i, r in registered.delimiters:
    if r.ch == ch:
      return i
  -1

proc snapshot*(): Registry =
  ## The current rules, for tests that register rules of their own and
  ## `restore` afterwards.
  registered

proc restore*(saved: Registry) =
  registered = saved
