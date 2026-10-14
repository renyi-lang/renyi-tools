# Every construct

This page uses each part of the Markdown subset once or more.

## Inline markup

Text can be **bold**, *italic* or `inline code`, and a link goes
[back to the index](index.html). Reserved characters are escaped: 1 < 2 && 3 > 2.

A `code span keeps <tags> & *stars*` as they are.

### Lists

- apples
- pears with **a bold word**
- a [link in a list](guide.html)

1. first step
2. second step, in `code`
3. third step

## A fenced block

```ry
function greet(name: Text) returns Text
  return "<b>{name}</b> & more"
end
```

The block above keeps its lines and escapes <b> and &.
