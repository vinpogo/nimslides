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
