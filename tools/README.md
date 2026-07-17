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
| `orphans [--locale L] [--list]` | Keys in a locale absent from the template (unreachable — gen-l10n only reads template keys) |
| `missing-detail LOCALE` | JSON `{key: {en, description, placeholders}}` for every key missing in LOCALE — feed to a translator, then to `fill` |
| `audit-identical [--locale L] [--list]` | Values byte-identical to the `en` template — a likely untranslated/copy-pasted string (brand names, acronyms, or shared official document names are expected false positives) |
| `audit-placeholders [--locale L] [--list]` | Values whose top-level `{placeholder}` tokens don't match the `en` template's — a near-certain bug, since a missing placeholder silently drops data at render time |
| `dead [--list]` | Template keys with no apparent reference in `lib/` or `test/` (heuristic) |
| `validate` | Parse every file and confirm the layout invariant |

Write (other keys left untouched):

| Command | What it does |
| --- | --- |
| `add KEY --translations '{"en":"...","fr":"..."}' [--description ...] [--placeholders '{"count":{"type":"int"}}']` | Add a new key. `en` is required; the template also gets the metadata block |
| `set KEY LOCALE VALUE` | Set or update one locale's value (KEY must already be in the template) |
| `fill LOCALE --translations-file PATH [--overwrite]` | Bulk-add/update many key/value translations for one locale in a single pass (PATH is `{"key":"value",...}`, typically produced by translating the output of `missing-detail`). Existing keys are left untouched unless `--overwrite` |
| `set-meta KEY [--description ...] [--placeholders '{...}']` | Update an existing key's template metadata in place, without touching translations |
| `rename OLD NEW` | Rename a key across every locale in place, preserving values + metadata |
| `delete KEY [KEY...]` | Remove keys and their `@KEY` metadata from every file (all-or-nothing: aborts if any key is unknown) |

Unknown options are rejected rather than ignored, so a typo fails loudly — and
an option that isn't valid for the specific command (e.g. `get KEY --description
x`) is rejected too, not silently dropped. To pass a value that begins with `--`
(e.g. `set KEY LOCALE -- --dash`), put it after a bare `--`. Add `--dry-run` to
any write command to see which files *would* change without touching disk.

The tool relies on one layout invariant: every top-level key sits on its own
line indented by exactly two spaces, in the same order as the parsed JSON, with
the closing `}` on its own column-0 line. This is what `make translations`
currently produces. If `validate` starts failing repo-wide after a Flutter /
`gen-l10n` / formatter bump, that output shape changed — update `_topKeyLine`
and `_assertInvariant` in `arb.dart` to match, don't hand-patch the files.

After any write command (`add`, `set`, `set-meta`, `rename`, `delete`), run
`make translations` to regenerate the Dart localizations — each changes either
the key set or a generated string. Run `fvm dart run tools/arb.dart help` for the
full reference.

> First run is slow (cold package build hooks); subsequent runs are sub-second.
