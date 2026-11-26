# NimSlides

Render a markdown file as slides in the terminal.

```sh
nimslides talk.md
nimslides --theme examples/themes/light.ini talk.md
nimslides --print-theme > my-theme.ini   # every style key, to start from
```

Slides are separated by a line of `---` with a blank line above and below.
An optional frontmatter at the top puts the author (left) and title
(centered) in the footer:

```markdown
---
title: Nim in the terminal
author: Vin
---

# First slide
```

A theme file restyles any element; sections set only the attributes they
name:

```ini
[slide]
bg = #1e1e2e
fg = 252

[heading.1]
fg = #ff5fd7
```

## Syntax highlighting

Fenced code with a language (```` ```nim ````) is highlighted by
[bat](https://github.com/sharkdp/bat) if it is on the `PATH`; the token
colors come from bat's theme (`BAT_THEME=GitHub nimslides talk.md` for a
light one), the card's background from nimslides' `code_fenced` style.
Without bat, or for a language bat doesn't know, code stays plain.

## Development

```sh
nix develop          # nim, nimble, nph, nimver, bat
nimble build
```
