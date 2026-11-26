Fenced code with a language:

```nim
proc greet(name: string): string =
  ## Says hello.
  result = "Hello, " & name & "!"

echo greet("world") # *not emphasis*, `not code`
```

An unlabeled tilde fence:

~~~
# not a heading
- not a list
~~~

A long line wraps instead of running off the card:

```sh
nim c -d:release --opt:speed --mm:orc --threads:on --out:build/nimslides src/nimslides.nim
```

With `bat` installed, code is highlighted for its language:

```python
def greet(name: str) -> str:
    return f"Hello, {name}!"  # a comment
```

```json
{ "name": "nimslides", "slides": 3, "dark": true }
```

A language bat doesn't know stays plain:

```nosuchlang
some code here
```
