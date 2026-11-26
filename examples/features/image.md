Images show as a placeholder with their alt text and address:
![The Nim crown](https://nim-lang.org/assets/img/logo.svg "Nim logo").

The alt text is plain: ![a *very* `tidy` desk](desk.jpg) loses its
markup. A reference works too: ![diagram][arch], ![arch][] or just
![arch].

[arch]: docs/architecture.png "Architecture"

Not images: a lone ! stays, \![escaped](x.png) stays, and so does
![undefined] without a definition.
