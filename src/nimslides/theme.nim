## Theme files: INI files that restyle the style keys of features and core.
##
## ```ini
## [heading.1]
## fg = #ff5fd7     # comments start with # or ; after whitespace
## italic = true    # bold stays on from the default
## ```
##
## A section names a style key (see "Style keys" in docs/architecture.md)
## and sets only the attributes it names; the rest keep the registered
## default. `formatTheme(registered.styles)` writes the defaults in the same
## format (`nimslides --print-theme`, `themes/default.ini`).

import std/[algorithm, parseutils, strutils, tables]
import ./core

type ThemeError* = object of ValueError ## a bad theme file; the message says where

const colorNames =
  ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]
  ## palette entries 0-7; `bright_<name>` are 8-15

proc parseColor*(s: string): Color =
  ## `default`, a palette index `0`-`255`, `#rrggbb`, or one of the 16 basic
  ## color names (`red`, `bright_red`, ...). Raises `ValueError`.
  let s = s.strip.toLowerAscii
  if s == "default":
    return Color()
  if s.len == 7 and s[0] == '#':
    var rgb: array[3, uint8]
    for i in 0 .. 2:
      var v: int
      if parseHex(s, v, 1 + 2 * i, 2) != 2:
        raise newException(ValueError, "bad color " & s.escape)
      rgb[i] = uint8(v)
    return Color(kind: ckRgb, r: rgb[0], g: rgb[1], b: rgb[2])
  if s.len > 0 and s.allCharsInSet(Digits):
    let n =
      try:
        parseInt(s)
      except ValueError:
        256
    if n > 255:
      raise newException(ValueError, "color index " & s & " is not in 0-255")
    return indexed(uint8(n))
  for i, name in colorNames:
    if s == name:
      return indexed(uint8(i))
    if s == "bright_" & name:
      return indexed(uint8(i + 8))
  raise newException(
    ValueError,
    "bad color " & s.escape & "; expected default, 0-255, \"#rrggbb\" or a name like red",
  )

proc parseBool(s: string): bool =
  case s.strip.toLowerAscii
  of "true":
    true
  of "false":
    false
  else:
    raise newException(ValueError, "expected true or false, not " & s.escape)

proc withoutComment(value: string): string =
  ## `value` up to a comment: `#` or `;` after whitespace, or at the start
  ## when followed by whitespace. So a value can itself start with `#`
  ## (`fg = #ff5fd7  # pink`).
  if value.len > 0 and value[0] in {'#', ';'} and
      (value.len == 1 or value[1] in Whitespace):
    return ""
  for i in 1 ..< value.len:
    if value[i] in {'#', ';'} and value[i - 1] in Whitespace:
      return value[0 ..< i].strip
  value

proc isComment(rest: string): bool =
  ## Whether `rest`, what follows a value or section on its line, is empty
  ## or a comment.
  rest.len == 0 or rest[0] in {'#', ';'}

proc parseTheme*(
    text: string, filename = "theme", defaults = registered.styles
): Table[string, Style] =
  ## The styles a theme file sets, each one its default from `defaults`
  ## with the file's attributes applied. Keys the file doesn't mention are
  ## not in the result. Raises `ThemeError` with "file:line: message".
  var key = ""
  var lineNo = 0
  proc fail(msg: string) =
    raise newException(ThemeError, filename & ":" & $lineNo & ": " & msg)

  for raw in text.splitLines:
    inc lineNo
    let line = raw.strip
    if line.len == 0 or line[0] in {'#', ';'}:
      continue
    if line[0] == '[':
      let close = line.find(']')
      if close < 0 or not line[close + 1 .. ^1].strip.isComment:
        fail "expected `[style.key]`, not " & line.escape
      key = line[1 ..< close].strip
      if key notin defaults:
        fail "unknown style key " & key.escape &
          " (nimslides --print-theme lists them all)"
      if key notin result:
        result[key] = defaults[key]
      continue
    let eq = line.find('=')
    if eq < 0:
      fail "expected `name = value`, not " & line.escape
    let name = line[0 ..< eq].strip
    var value = line[eq + 1 .. ^1].strip
    if value.startsWith('"'):
      let close = value.find('"', 1)
      if close < 0 or not value[close + 1 .. ^1].strip.isComment:
        fail name & ": bad quoting in " & value.escape
      value = value[1 ..< close]
    else:
      value = value.withoutComment
    if key == "":
      fail "`" & name & "` comes before any [section]"
    if value == "":
      fail "`" & name & "` has no value; expected `" & name & " = ...`"
    try:
      case name
      of "fg":
        result[key].fg = parseColor(value)
      of "bg":
        result[key].bg = parseColor(value)
      of "bold":
        result[key].bold = parseBool(value)
      of "italic":
        result[key].italic = parseBool(value)
      of "underline":
        result[key].underline = parseBool(value)
      of "dim":
        result[key].dim = parseBool(value)
      of "strikethrough":
        result[key].strikethrough = parseBool(value)
      else:
        fail "unknown attribute " & name.escape &
          "; expected fg, bg, bold, italic, underline, dim or strikethrough"
    except ThemeError as err:
      raise err
    except ValueError as err:
      fail name & ": " & err.msg

proc loadTheme*(path: string): Table[string, Style] =
  ## `parseTheme` of the file at `path`. Raises `ThemeError`, also when the
  ## file can't be read.
  let text =
    try:
      readFile(path)
    except IOError as e:
      raise newException(ThemeError, path & ": cannot read: " & e.msg)
  parseTheme(text, path)

proc `$`(c: Color): string =
  ## `c` in the syntax `parseColor` reads.
  case c.kind
  of ckDefault:
    "default"
  of ckIndexed:
    $c.index
  of ckRgb:
    "#" & (c.r.toHex & c.g.toHex & c.b.toHex).toLowerAscii

proc formatTheme*(styles: Table[string, Style]): string =
  ## `styles` as a theme file, sorted by key, with every attribute written
  ## out, so it lists each themable element and what can be set on it.
  result =
    "# nimslides default theme, written by `nimslides --print-theme`.\n" &
    "# Copy it, keep the sections and attributes you change, delete the rest.\n" &
    "# Colors: default, 0-255, #rrggbb, black ... white, bright_black ... bright_white.\n"
  var keys: seq[string]
  for k in styles.keys:
    keys.add k
  keys.sort
  for k in keys:
    let s = styles[k]
    result.add "\n[" & k & "]\n"
    result.add "fg = " & $s.fg & "\n"
    result.add "bg = " & $s.bg & "\n"
    result.add "bold = " & $s.bold & "\n"
    result.add "italic = " & $s.italic & "\n"
    result.add "underline = " & $s.underline & "\n"
    result.add "dim = " & $s.dim & "\n"
    result.add "strikethrough = " & $s.strikethrough & "\n"

proc defaultTheme*(): string =
  ## Every registered style key with its default, as a theme file.
  formatTheme(registered.styles)
