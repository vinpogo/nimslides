Run `nimble test` before you commit, then `nimble build`.

Use two backticks to show one: ``a `tick` inside``. A
single space is stripped from each side, so `` `x` `` shows
the backticks alone.

Nothing is parsed inside: `*not emphasis*`, `\*`, `[no](link)`
and `<b>` stay literal.

A span can run over a line break: `foo
bar` becomes one line of code.

Unmatched backticks stay literal: ```bar`` and `baz.

Long spans wrap at their spaces like other words: `nim c -r --hints:off tests/features/test_code_span.nim`
