+++
title = "Code Example"
date = 2017-09-24

[taxonomies]
categories = ["demo"]
tags = ["code", "example"]
+++

Have code snippets complete with **clipboard functionality** and **fancy
language tags**. No more boring code snippets in your pages. Oh yeah baby! Click
on this article to see some code in action.

<!-- more -->

```rust
fn main() {
    println!("Hello World");
}
```

Same snippet with line numbers:

```rust,linenos
fn main() {
    println!("Hello World");
}
```

Same snippet with line numbers and line highlighting:

```rust,hl_lines=2,linenos
fn main() {
    println!("Hello World");
}
```

Python example:

```python
def main():
    print("Hello, world!")
```

This is another code block with syntax highlighting. It's pretty cool, right?
You can also have inline code like this: `var example = true`.

```js
function debounce(func, wait) {
  var timeout;

  return function () {
    var context = this;
    var args = arguments;
    clearTimeout(timeout);

    timeout = setTimeout(function () {
      timeout = null;
      func.apply(context, args);
    }, wait);
  };
}
```

C++ example:

```cpp
#include <iostream>
using namespace std;
int main() {
    cout << "Hello, World!" << endl;
    return 0;
}
```
