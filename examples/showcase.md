# Heading 1

## Heading 2

### Heading 3

#### Heading 4

##### Heading 5

###### Heading 6

Setext Heading 1
================

Setext Heading 2
----------------

A paragraph with *italic*, _also italic_, **bold**, __also bold__,
***bold italic***, ~~strikethrough~~ and `inline code`. Snake_case_words
stay as they are, and \*escaped\* characters are literal.

This line ends with two spaces  
so this one starts after a hard break,\
and so does this one, after a backslash.

Links come [inline](https://nim-lang.org "Nim"), as a [reference][nim],
as a [collapsed reference][], as a bare <https://example.com> autolink, or
as an email: <hello@example.com>.

![An image](https://nim-lang.org/assets/img/logo.svg)

[nim]: https://nim-lang.org
[collapsed reference]: https://github.com/nim-lang/Nim

> A block quote with **bold** text that is long enough to wrap onto a
> second line when the terminal is narrow.
>
> > And a nested quote.

- Unordered item
- Another item with a lot of text so that it needs to wrap around to the
  next line, indented under the first
  - Nested item
    - Deeper nested item
* A different bullet character starts a new list
+ So does this one

1. First
2. Second
   1. Nested ordered
   2. Another
3. Third

7) Lists can start at any number,
8) and `)` works as a delimiter too

- [x] A finished task
- [ ] An open task

***

```nim
proc greet(name: string): string =
  ## Fenced code block with a language.
  result = "Hello, " & name & "!"

echo greet("world")
```

~~~
Tilde fences work too.
~~~

    Indented code block,
    four spaces deep.

| Left aligned | Centered | Right aligned |
|:-------------|:--------:|--------------:|
| `code`       | **bold** |          1.00 |
| *italic*     |    ok    |         10.50 |
| long cell text that needs to wrap when narrow | x | 100.25 |

___

<!-- HTML comments are hidden: good for speaker notes. -->

Inline <kbd>HTML</kbd> is shown as-is.
