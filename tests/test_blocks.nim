## The block driver and the paragraph hooks, with rules registered by this
## file only.

import std/[strutils, tables, unittest]
import ./helpers

type
  Marker = ref object of BlockNode # what the test block rules build
    text: string

  Box = ref object of BlockNode # a test container
    children: seq[BlockNode]

  Defs = ref object of RootObj # document state of the test start hook
    table: Table[string, string]

method layout(node: Marker, ctx: LayoutCtx): seq[Line] =
  if node.text.len > 0:
    result.add @[Span(text: node.text)]

method layout(node: Box, ctx: LayoutCtx): seq[Line] =
  for line in ctx.renderBlocks(node.children, ctx.width - 2):
    result.add Span(text: if line.len == 0: "|" else: "| ") & line

proc lineRule(name, prefix: string, priority = 0, interrupts = false): BlockRule =
  ## Takes one line starting with `prefix` and shows it as "<name>: rest".
  BlockRule(
    name: name,
    priority: priority,
    interruptsParagraph: interrupts,
    parse: proc(p: BlockParser): BlockNode =
      if p.line.startsWith(prefix):
        result = Marker(text: name & ": " & p.line[prefix.len .. ^1])
        p.advance
    ,
  )

let empty = snapshot()

suite "paragraphs":
  setup:
    restore empty

  test "blank lines separate paragraphs, which are word wrapped":
    check render("one two three four\nfive\n\n\nsix", 9) ==
      @["one two", "three", "four five", "", "six"]
    check parse("a\n\nb").len == 2
    check parse("a\n\nb")[0] of Paragraph
    check Paragraph(parse("  a\n   b  ")[0]).raw == "a\nb"

  test "markdown stays literal without features":
    check render("# Title\n\n*text*") == @["# Title", "", "*text*"]

  test "tabs are expanded to 4-column stops":
    check expandTabs("\tx") == "    x"
    check expandTabs("ab\tx") == "ab  x"
    check newBlockParser(@["a\tb"], newDocCtx()).line == "a   b"

suite "block rules":
  setup:
    restore empty

  test "rules run by priority, ties broken by name":
    registerBlock lineRule("b", "!", priority = 10)
    registerBlock lineRule("a", "!", priority = 10)
    registerBlock lineRule("c", "!!", priority = 5)
    check registered.blockRules[0].name == "c"
    check render("!x\n\n!!y") == @["a: x", "", "c: y"]

  test "only interrupting rules end a paragraph":
    registerBlock lineRule("quiet", "?")
    registerBlock lineRule("loud", "!", interrupts = true)
    check render("text\n?a\n!b") == @["text ?a", "", "loud: b"]

  test "rules see whether they are asked to interrupt":
    registerBlock BlockRule(
      name: "notAfterParagraph",
      interruptsParagraph: true,
      parse: proc(p: BlockParser): BlockNode =
        if p.line == "!" and not p.interrupting:
          p.advance
          result = Marker(text: "bang")
      ,
    )
    check render("!\ntext\n!") == @["bang", "", "text !"]

  test "blocks with no lines take no space":
    registerBlock BlockRule(
      name: "hidden",
      parse: proc(p: BlockParser): BlockNode =
        if p.line.startsWith("%"):
          p.advance
          result = Marker(text: "")
      ,
    )
    check render("a\n\n%hidden\n\nb") == @["a", "", "b"]

  test "containers parse their content as blocks, one level deeper":
    registerBlock lineRule("x", "!", interrupts = true)
    registerBlock BlockRule(
      name: "box",
      parse: proc(p: BlockParser): BlockNode =
        let lines = p.takeWhile(
          proc(l: string): bool =
            l.startsWith(">")
        )
        if lines.len == 0:
          return nil
        var inner: seq[string]
        for l in lines:
          inner.add l[1 .. ^1].strip(trailing = false)
        Box(children: p.parseBlocks(inner)),
    )
    check render(">aa bb\n>!c\n>\n>> d", 6) ==
      @["| aa", "| bb", "|", "| x: c", "|", "| | d"]

suite "paragraph hooks":
  setup:
    restore empty

  test "a closer turns the paragraph into another block":
    registerParagraphCloser ParagraphCloser(
      name: "underline",
      close: proc(p: BlockParser): ParagraphBuild =
        if p.line.startsWith("==="):
          p.advance
          result = proc(lines: seq[string]): BlockNode =
            Marker(text: lines.join(" ").toUpperAscii)
      ,
    )
    check render("Some\ntitle\n===\nnext") == @["SOME TITLE", "", "next"]
    check render("===") == @["==="] # a closer never starts a paragraph

  test "closers come before interruptions":
    registerBlock lineRule("rule", "===", interrupts = true)
    check render("title\n===") == @["title", "", "rule: "]
    registerParagraphCloser ParagraphCloser(
      name: "underline",
      close: proc(p: BlockParser): ParagraphBuild =
        if p.line == "===":
          p.advance
          result = proc(lines: seq[string]): BlockNode =
            Marker(text: "heading")
      ,
    )
    check render("title\n===") == @["heading"]

  test "start hooks take leading lines into document state":
    registerParagraphStart ParagraphStart(
      name: "defs",
      consume: proc(lines: seq[string], doc: DocCtx): int =
        if lines[0].startsWith("[") and "]: " in lines[0]:
          let (key, val) =
            (lines[0][1 ..< lines[0].find(']')], lines[0].split("]: ")[1])
          doc.state("defs", Defs).table[key] = val
          result = 1
      ,
    )
    registerInline InlineRule(
      name: "use",
      triggers: {'@'},
      parse: proc(p: InlineParser): InlineNode =
        let key = $p.peek(1)
        p.pos += 2
        Text(text: p.doc.state("defs", Defs).table.getOrDefault(key, "?")),
    )
    # Inline text is parsed after all blocks, so later definitions count.
    check render("see @a and @b\n\n[a]: one\n[b]: two\nrest") ==
      @["see one and two", "", "rest"]
    check render("[a]: one\n[b]: two") == newSeq[string]()

    registerParagraphCloser ParagraphCloser(
      name: "underline",
      close: proc(p: BlockParser): ParagraphBuild =
        if p.line == "===":
          p.advance
          result = proc(lines: seq[string]): BlockNode =
            Marker(text: "heading " & lines.join(" "))
      ,
    )
    check render("[a]: one\ntitle\n===") == @["heading title"]
    # Nothing left to underline: the closing line is parsed afresh.
    check render("[a]: one\n===") == @["==="]
