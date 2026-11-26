Indent a block by four spaces to show it as code:

    proc greet(name: string): string =
      ## Says hello.
      result = "Hello, " & name & "!"

    echo greet("world") # *not emphasis*, `not code`

An indented line right after a paragraph
    stays part of the paragraph.

Markdown inside is literal, and long lines wrap instead of running off the card:

    # not a heading
    - not a list
    nim c -d:release --opt:speed --mm:orc --threads:on --out:build/nimslides src/nimslides.nim
    日本語のテキストも折り返します、幅に合わせて。
