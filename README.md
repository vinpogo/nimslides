# NimSlides

Render a markdown file as slides in the terminal.

```sh
nimslides talk.md
nimslides --theme examples/themes/light.ini talk.md
nimslides --print-theme > my-theme.ini   # every style key, to start from
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

## Planned features

- Syntax-highlighted code blocks

## Development

```sh
nix develop          # nim, nimble, nph, nimver
nimble build
```
