# tools/

Developer scripts for this repo. Run everything through `fvm` (see `AGENTS.md`).
Each script is documented in its own section below.

## arb.dart — manage the `.arb` localization files

The files under `localization/` are large and easy to corrupt by hand. This tool
reads them with a JSON parser and mutates them with surgical line edits, so every
other key stays byte-for-byte unchanged and JSON never breaks. It refuses to edit
a file that doesn't match the expected 2-space-per-top-level-key layout.

```
fvm dart run tools/arb.dart <command>
```

Read:

| Command | What it does |
| --- | --- |
| `get KEY [--locale L]` | Print the description and the value across locales |
| `check KEY` | Which locales have KEY, which are missing it |
| `missing [--locale L] [--list]` | Keys in the `en` template absent from a locale |
| `dead [--list]` | Template keys with no apparent reference in `lib/` or `test/` (heuristic) |
| `validate` | Parse every file and confirm the layout invariant |

Write (other keys left untouched):

| Command | What it does |
| --- | --- |
| `add KEY --translations '{"en":"...","fr":"..."}' [--description ...] [--placeholders '{"count":{"type":"int"}}']` | Add a new key. `en` is required; the template also gets the metadata block |
| `set KEY LOCALE VALUE` | Set or update one locale's value (KEY must already be in the template) |
| `set-meta KEY [--description ...] [--placeholders '{...}']` | Update an existing key's template metadata in place, without touching translations |
| `rename OLD NEW` | Rename a key across every locale in place, preserving values + metadata |
| `delete KEY` | Remove KEY and its `@KEY` metadata from every file |

Unknown options are rejected rather than ignored, so a typo fails loudly. To
pass a value that begins with `--` (e.g. `set KEY LOCALE -- --dash`), put it
after a bare `--`.

After any write command (`add`, `set`, `set-meta`, `rename`, `delete`), run
`make translations` to regenerate the Dart localizations — each changes either
the key set or a generated string. Run `fvm dart run tools/arb.dart help` for the
full reference.

> First run is slow (cold package build hooks); subsequent runs are sub-second.
