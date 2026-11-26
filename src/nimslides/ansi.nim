## Turns styled lines into text with ANSI escape codes.

import render

proc sgr(style: Style): string =
  ## The escape code that switches from the default style to `style`.
  var codes: seq[string]
  if style.bold:
    codes.add "1"
  if style.dim:
    codes.add "2"
  if style.italic:
    codes.add "3"
  if style.underline:
    codes.add "4"
  if style.fg >= 0:
    codes.add "38;5;" & $style.fg
  if style.bg >= 0:
    codes.add "48;5;" & $style.bg
  if codes.len > 0:
    result = "\e["
    for i, c in codes:
      if i > 0:
        result.add ';'
      result.add c
    result.add 'm'

proc toAnsi*(line: Line, color = true): string =
  ## `line` as terminal text; with `color = false`, the text alone.
  for span in line:
    let code =
      if color:
        sgr(span.style)
      else:
        ""
    if code.len > 0:
      result.add code & span.text & "\e[0m"
    else:
      result.add span.text
