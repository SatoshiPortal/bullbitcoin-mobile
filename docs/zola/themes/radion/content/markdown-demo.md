+++
title = "Markdown Formatting Test"
date = 2024-12-13

[extra]
toc = true
+++

This page demonstrates various Markdown formatting features that can be used in
the theme. The following sections showcase different elements, such as blockquotes,
headings, lists, and more.

<!-- more -->

## Markdown Text Formatting Options

**Some bold text**. _Italic text_. **_Bold and italic text_**.
~~Strikethrough text~~. `Inline code`.

## Collapsible Sections

**Open sections by default**:

<details open> 
<summary>Click to close</summary>

This is an open section.

</details>

**Closed sections by default**:

<details>
<summary>Click to open</summary>

Peak-a-boo

</details>

## Blockquotes

> This is a blockquote example. You can add multiple levels of blockquotes
> to create a nested structure.
>
> > For example, this is a second level blockquote.

## Headings

### H3 Header Example

This is an example of an H3 header.

#### H4 Header Example

This is an example of an H4 header.

## Tables

| Header 1 | Header 2 | Header 3 |
| -------- | -------- | -------- |
| Row 1    | Row 1    | Row 1    |
| Row 2    | Row 2    | Row 2    |
| Row 3    | Row 3    | Row 3    |

with alignment:

| Left-Aligned | Centered  |    Right-Algned |
| :----------- | :-------: | --------------: |
| foo          | fibonacci | some more stuff |
| bar          |    42     | (idk what else) |

## Footnotes

Footnote example[^1]

Some other footnote that is inline[^2]. As you can see, it just blends right in!

See below for an example of a footnote with multiple paragraphs and code[^3].

## Lists

### Unordered List

- Item 1
- Item 2
- Item 3

### Ordered List

1. Item 1
   1. Indented item
   2. Yet another indented item
2. Item 2
3. Item 3

### Nested Lists

Example of 3-level nested ordered lists:

1. a
2. First sublist:

   1. One (with additional sublist)

      1. Another
      2. ordered
      3. sublist.

   2. Two

   3. Three

3. c
4. d

---

Example of 3-level nested unordered lists:

- a

  - b
  - c

- d
  - e
  - f
    - g
    - h

## Code Blocks

```rust
fn main() {
    println!("Hello, world!");
}
```

```
Some text block
```

## Inline Code

This is an example of `inline code`. You can use backticks to highlight code
snippets within a paragraph.

## Links

This is an [example link](https://example.com). You can add links to text by
wrapping the text in square brackets and the URL in parentheses.

---

[^1]:
    Lorem ipsum veniam in cillum deserunt nostrud cupidatat pariatur in do
    irure magna cillum tempor minim commodo labore voluptate mollit amet enim
    nostrud eiusmod ut est cillum esse qui enim anim dolor consequat eiusmod
    irure cillum Lorem occaecat nostrud dolor magna labore elit veniam
    voluptate eiusmod labore in proident aliqua magna aliqua dolore sint cillum
    adipisicing nulla aute anim incididunt veniam ullamco eu eu commodo magna
    sunt dolore fugiat voluptate eu eu fugiat anim mollit laboris deserunt ex
    ex irure enim cupidatat elit consequat Lorem consectetur adipisicing et
    amet id laboris pariatur ea ut exercitation Lorem velit et nisi nulla
    occaecat voluptate

[^2]: Wikipedia article on a cool topic: [https://en.wikipedia.org/wiki/Isometric_projection](https://en.wikipedia.org/wiki/Isometric_projection)

[^3]:
    Here's one with multiple paragraphs and code. This is the first paragraph
    of the footnote.

    Indent paragraphs to include them in the footnote.

    ```python
    print("Hello word")
    ```

    Add as many paragraphs as you like.
