## Fenced code blocks: ``` or ~~~ fences, shown as a shaded card with the
## language in its top row. The content is literal and hard-wrapped.
##
## Syntax highlighting: if `bat` is on the PATH, code with a language is
## colored by `bat --color=always` (colors from bat's theme, e.g.
## `BAT_THEME`). Without bat, or for a language bat doesn't know, the card
## stays plain.

import std/[os, osproc, streams, strutils, tables]
import ../core

const pad = 2 ## columns of shading left of the code, and right of the language

type FencedCode* = ref object of BlockNode
  info*: string ## the info string, backslash escapes processed
  lang*: string ## its first word, "" if none; kept for syntax highlighting
  lines*: seq[string] ## the content lines, fence indentation removed

proc fenceAt(line: string): tuple[indent: int, ch: char, len: int] =
  ## The fence that `line` starts with, or `len == 0` if none.
  let indent = indentOf(line)
  if indent > 3 or indent >= line.len or line[indent] notin {'`', '~'}:
    return
  let ch = line[indent]
  var i = indent
  while i < line.len and line[i] == ch:
    inc i
  if i - indent >= 3:
    result = (indent, ch, i - indent)

proc closes(line: string, ch: char, minLen: int): bool =
  ## Whether `line` is a closing fence of `ch`, at least `minLen` long.
  let f = fenceAt(line)
  f.len >= minLen and f.ch == ch and line[f.indent + f.len .. ^1].isBlank

proc dedent(line: string, n: int): string =
  ## `line` without up to `n` leading spaces.
  line[min(n, indentOf(line)) .. ^1]

proc parseFence(p: BlockParser): BlockNode =
  let open = fenceAt(p.line)
  if open.len == 0:
    return nil
  let info = p.line[open.indent + open.len .. ^1].strip
  if open.ch == '`' and '`' in info:
    return nil
  let words = info.splitWhitespace
  let node = FencedCode(
    info: info.resolveEscapes,
    lang:
      if words.len > 0:
        words[0].resolveEscapes
      else:
        "",
  )
  p.advance
  while not p.eof and not p.line.closes(open.ch, open.len):
    node.lines.add p.line.dedent(open.indent)
    p.advance
  p.advance # past the closing fence; unclosed fences run to the end
  node

var highlighter* = "bat" ## the program that colors code; tests point it elsewhere

var cache: Table[string, seq[Line]]
  ## highlighted lines by command, language and code; empty = not highlighted.
  ## The viewer lays slides out again on every resize.

proc sgr(style: var Style, params: string) =
  ## Applies the SGR parameters `params` (as in `ESC[1;38;5;81m`) to `style`.
  var codes: seq[int]
  for p in params.split(';'):
    codes.add(
      try:
        parseInt(p)
      except ValueError:
        0 # an empty parameter means 0
    )
  var i = 0
  proc next(): int =
    inc i
    if i < codes.len:
      codes[i]
    else:
      -1

  proc extended(): Color =
    ## The color after 38 or 48: `5;n` or `2;r;g;b`; default if malformed.
    case next()
    of 5:
      let n = next()
      if n in 0 .. 255:
        result = indexed(uint8(n))
    of 2:
      let (r, g, b) = (next(), next(), next())
      if r in 0 .. 255 and g in 0 .. 255 and b in 0 .. 255:
        result = Color(kind: ckRgb, r: uint8(r), g: uint8(g), b: uint8(b))
    else:
      discard

  while i < codes.len:
    let c = codes[i]
    case c
    of 0:
      style = Style()
    of 1:
      style.bold = true
    of 2:
      style.dim = true
    of 3:
      style.italic = true
    of 4:
      style.underline = true
    of 9:
      style.strikethrough = true
    of 22:
      style.bold = false
      style.dim = false
    of 23:
      style.italic = false
    of 24:
      style.underline = false
    of 29:
      style.strikethrough = false
    of 30 .. 37:
      style.fg = indexed(uint8(c - 30))
    of 90 .. 97:
      style.fg = indexed(uint8(c - 90 + 8))
    of 38:
      style.fg = extended()
    of 39:
      style.fg = Color()
    of 40 .. 47:
      style.bg = indexed(uint8(c - 40))
    of 100 .. 107:
      style.bg = indexed(uint8(c - 100 + 8))
    of 48:
      style.bg = extended()
    of 49:
      style.bg = Color()
    else:
      discard
    inc i

proc parseAnsi*(s: string): seq[Line] =
  ## Text with ANSI color codes (SGR, `ESC[...m`) as styled lines, one per
  ## "\n". Other escape sequences are dropped.
  var style = Style()
  var line: Line
  var text = ""
  template flush() =
    if text.len > 0:
      if line.len > 0 and line[^1].style == style:
        line[^1].text.add text
      else:
        line.add Span(text: text, style: style)
      text = ""

  var i = 0
  while i < s.len:
    case s[i]
    of '\e':
      flush()
      if i + 1 < s.len and s[i + 1] == '[':
        var j = i + 2
        while j < s.len and s[j] in {'0' .. '9', ';', ':', '?'}:
          inc j
        if j < s.len and s[j] == 'm':
          style.sgr(s[i + 2 ..< j])
        i = j + 1
      else:
        i += 2
    of '\n':
      flush()
      result.add line
      line = @[]
      inc i
    else:
      text.add s[i]
      inc i
  flush()
  result.add line

proc run(exe, lang, code: string): seq[Line] =
  ## `code` colored by `exe`, or empty if it fails or changes the text.
  try:
    let p = startProcess(
      exe,
      args = [
        "--language", lang, "--color=always", "--style=plain", "--paging=never",
        "--wrap=never",
      ],
      options = {},
    )
    defer:
      p.close
    p.inputStream.write code
    p.inputStream.close
    let output = p.outputStream.readAll
    if p.waitForExit != 0:
      return
    var lines = output.parseAnsi
    if lines.len > 0 and lines[^1].len == 0:
      lines.setLen lines.len - 1 # after the last "\n"
    var plain: seq[string]
    for line in lines:
      plain.add line.plain
    if plain.join("\n") & "\n" == code:
      result = lines
  except OSError, IOError:
    discard

proc highlight(lang: string, lines: seq[string]): seq[Line] =
  ## `lines` colored for `lang` by the `highlighter`, or empty if there is
  ## no language, no highlighter, or it can't color them.
  if lang == "" or lines.len == 0:
    return
  let code = lines.join("\n") & "\n"
  let key = highlighter & "\0" & lang & "\0" & code
  if key notin cache:
    let exe = findExe(highlighter)
    cache[key] =
      if exe == "":
        @[]
      else:
        run(exe, lang, code)
  cache[key]

method layout(node: FencedCode, ctx: LayoutCtx): seq[Line] =
  let shade = ctx.style("code_fenced")
  let lang = node.lang.fit(max(0, ctx.width - pad))
  if lang.width == 0:
    result.add ctx.filledRow(shade)
  else:
    let right = min(pad, ctx.width - lang.width)
    let left = ctx.width - lang.width - right
    var top: Line
    if left > 0:
      top.add Span(text: ' '.repeat(left), style: shade)
    top.add Span(text: lang.text, style: shade.merge(ctx.style("code_fenced.lang")))
    top.add Span(text: ' '.repeat(right), style: shade)
    result.add top
  let colored = highlight(node.lang, node.lines)
  if colored.len > 0:
    result.add ctx.literalRows(colored, shade, lead = pad)
  else:
    result.add ctx.literalRows(node.lines, shade, lead = pad)
  result.add ctx.filledRow(shade)

registerBlock BlockRule(
  name: "code_fenced", priority: 20, interruptsParagraph: true, parse: parseFence
)

defaultStyle("code_fenced", Style(fg: indexed(252), bg: indexed(235)))
defaultStyle(
  "code_fenced.lang", Style(italic: true, fg: indexed(243), bg: indexed(235))
)
