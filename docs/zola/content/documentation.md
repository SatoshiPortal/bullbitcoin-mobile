+++
title = "Documentation Guide"
description = "How to work with Bull Mobile documentation using Zola"
date = 2025-07-04
authors = ["ethicnology"]

[taxonomies]
categories = ["dev"]
tags = ["documentation", "zola"]

[extra]
toc = true
+++

This guide explains how to work with Bull Mobile's documentation system built with [Zola](https://www.getzola.org/).

## What is Zola?

Zola is a fast static site generator written in Rust. It's used to build our documentation site from Markdown files.

## Project Structure

```
docs/zola/
├── config.toml          # Site configuration
├── content/             # Markdown content files
│   ├── _index.md        # Homepage
│   ├── getting-started.md
│   ├── security.md
│   └── ...
├── static/              # Static assets (images, videos, etc.)
│   ├── bull/
│   └── coldcard-q/
├── themes/              # Zola theme (radion)
└── templates/           # Custom templates (if needed)
```

## Adding New Content

### Creating a New Page

1. Create a new `.md` file in the `content/` directory
2. Add frontmatter at the top:

```markdown
+++
title = "Watch-Only Wallets"
description = "Descriptors, xpub, ypub, zpub…"
date = 2025-07-04
authors = ["ethicnology", "ishi"]

[taxonomies]
categories = ["guides"]
tags = ["watch only", "ColdCard Q", "wallet"]

[extra]
toc = true
+++

Your content here...
```

### Frontmatter Options

- **title**: Page title (required)
- **description**: Page description for SEO
- **date**: Publication date
- **taxonomies**: Categories and tags for organization
- **extra.toc**: Enable table of contents

### Available Categories

- `guides` - How-to guides and tutorials
- `security` - Security-related content
- `technical` - Technical documentation
- `dev` - Developer documentation
- `support` - Support and troubleshooting

## Code Blocks

### Syntax Highlighting

```dart
// Dart code example
class WalletService {
  Future<void> initializeWallet() async {
    // Your code here
  }
}
```

### Configuration Examples

```toml
[network]
network_type = "mainnet"
```

```json
{
  "servers": [
    "electrum.example.com:50002"
  ]
}
```

## Building and Serving

### Development Server

```bash
cd docs/zola
zola serve
```

This starts a local server at `http://127.0.0.1:1111`

### Build for Production

```bash
cd docs/zola
zola build
```

This creates a `public/` directory with the built site.

## Theme Features

The radion theme provides:

- **Dark/Light Mode**: Toggle in the top navigation
- **Search**: Full-text search across all content
- **Categories & Tags**: Browse content by topic
- **Table of Contents**: Auto-generated for pages with `toc = true`
- **Code Highlighting**: Syntax highlighting for code blocks
- **Responsive Design**: Works on mobile and desktop

### Getting Help

- [Zola Documentation](https://www.getzola.org/documentation/getting-started/overview/)
- [Radion Theme Documentation](https://github.com/micahkepe/radion)
- Check existing content for examples
