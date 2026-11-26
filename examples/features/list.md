- Bullets change with the nesting depth
  - second level
    - third level
      - fourth level
- A long item wraps with a hanging indent, so every row of
  the text lines up under its first word.
lazy lines without indent still continue the paragraph

+ A different bullet character starts a new list.

8. Ordered lists keep their start number,
9. and the numbers are right-aligned
10. so the text lines up.

1) The `)` delimiter works too.

- A loose list has blank lines between items.

- Each item gets a blank row.

- An item can hold several blocks:

  ```nim
  echo "code inside a list"
  ```

Tasks:

- [x] **Write** the parser
- [ ] Review it
- [X] Upper-case X counts as done
- [ ]not a task: no space after the brackets
