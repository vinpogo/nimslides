| Feature       | Status | Lines |
| :------------ | :----: | ----: |
| headings      | done   |    90 |
| *emphasis*    | done   |    35 |
| `code_span`   | done   |    60 |
| tables        | new    |   220 |

Columns align left, centre or right, and pipes are optional:

Left | Centre | Right
:--- | :---: | ---:
a | b | c
`a \| b` | escaped \| pipe | **bold**

Short rows are padded and long rows are cut:

| one | two |
| --- | --- |
| only one |
| a | b | dropped |

A wide table shrinks its widest column and wraps the cells, so rows grow taller:

| Option | Description |
| ------ | ----------- |
| `--width` | Sets the width of the slide in columns. Without it, nimslides uses the width of the terminal window. |
| `--theme` | Picks a colour theme. |

A table with only a header:

| empty | table |
| ----- | ----- |

Not a table, because the header and delimiter rows differ:

| a | b |
| --- |
