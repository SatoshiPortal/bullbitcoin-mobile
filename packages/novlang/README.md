# novlang

Store-constrained vocabulary. **The catalogue words are the real words**
(`localization/app_<lang>.arb` and the feature catalogues say *swap* and
*exchange*). A store that forbids
a word gets a substitute only where it applies, and a superuser always sees the
real words.

| Piece | Role |
|---|---|
| `manifest.yaml` | The catalogues (`app`, the root one, and feature catalogues such as `quick_actions`, each named by the package whose `l10n.yaml` generates it) and each forced word: store, the word, its substitute, the catalogue keys that carry it |
| `lib/l10n/novlang_<lang>.arb` | One override per manifest entry and language (27), keyed `<catalogue>__<key>_<store>`; gen-l10n turns them into `NovlangLocalizations` |
| `lib/src/policy.dart` | `NovlangPolicy` and the pure `resolveNovlangPolicy(platform, isSuperuser)` |
| `../../tools/novlang_bridge.dart` | Dev-only, run by `make translations`: generates (git-ignored) `lib/generated/novlang/novlang_<catalogue>_localizations.dart`, one `Novlang<Class>Delegate` per catalogue that wraps the catalogue's own delegate and that the app composes in its place (`novlangLocalizationsDelegates` for the root one) |

Policy: superuser → none; otherwise iOS → apple, Android → google (nothing is
substituted for Google), other platforms → none; the superuser flag still being
unknown (`null`) means the store constraint of the platform applies.

## Add a word a store forces

1. Add the entry to `manifest.yaml`. A new feature catalogue is declared under
   `catalogues` first, and the app composes its generated delegate wherever it
   provided the catalogue's delegate.
2. Add `<catalogue>__<key>_<store>` to `novlang_en.arb` (with the `@` metadata
   and placeholders of the catalogue message) and its translation to the other 26
   files; use the same words as the catalogue for everything else (where the
   catalogue lacks a language, the words it falls back to, usually English).
3. `make translations`, then `cd packages/novlang && fvm flutter test`.

A key renamed or removed from its catalogue fails `make translations`; a missing
override fails compilation; the tests fail on a missing language, a changed
placeholder, or a forbidden word in an override.

The legal disclosures, search keywords, bank/Interac/SEPA/SPEI rail names, NFC,
PSBT wording and RecoverBull text are deliberately outside the manifest.
