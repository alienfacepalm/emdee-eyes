# Code and tables

## Fenced code block

```sh
#!/bin/sh
echo "glow syntax-highlights this by language"
```

```python
def greet(name: str) -> str:
    return f"hello, {name}"
```

## Table

| Command          | What it does                          |
| ---------------- | -------------------------------------- |
| `emdee-eyes file.md`  | Render one file, paged                 |
| `emdee-eyes dir/`     | Browse markdown files in a directory   |
| `emdee-eyes a.md b.md` | Render several files in one pager     |

## Task list

- [x] Write the renderer
- [x] Handle multiple files
- [ ] Add syntax highlighting themes
