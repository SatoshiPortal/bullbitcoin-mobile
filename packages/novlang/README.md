# novlang

Store-constrained vocabulary. **The catalogue words are the real words**
(`localization/app_<lang>.arb` says *swap* and *exchange*). A store that forbids
a word gets a substitute only where it applies, and a superuser always sees the
real words.

| Piece | Role |
|---|---|
| `manifest.yaml` | Each forced word: store, the word, its substitute, the catalogue keys that carry it |
| `lib/l10n/novlang_<lang>.arb` | One override per manifest entry and language (27), keyed `<catalogue>__<key>_<store>`; gen-l10n turns them into `NovlangLocalizations` |
| `lib/src/policy.dart` | `NovlangPolicy` and the pure `resolveNovlangPolicy(platform, isSuperuser)` |
| `../../tools/novlang_bridge.dart` | Dev-only, run by `make translations`: generates (git-ignored) `lib/generated/novlang/novlang_app_localizations.dart` with the delegate the app composes before `AppLocalizations.delegate` |

Policy: superuser → none; otherwise iOS → apple, Android → google (nothing is
substituted for Google), other platforms → none; the superuser flag still being
unknown (`null`) means the store constraint of the platform applies.

## Add a word a store forces

1. Add the entry to `manifest.yaml`.
2. Add `<catalogue>__<key>_<store>` to `novlang_en.arb` (with the `@` metadata
   and placeholders of the catalogue message) and its translation to the other 26
   files; use the same words as the catalogue for everything else.
3. `make translations`, then `cd packages/novlang && fvm flutter test`.

A key renamed or removed from the catalogue fails `make translations`; a missing
override fails compilation; the tests fail on a missing language, a changed
placeholder, or a forbidden word in an override.

The legal disclosures, search keywords, bank/Interac/SEPA/SPEI rail names, NFC,
PSBT wording and RecoverBull text are deliberately outside the manifest.

## Forcing the Apple wording (development)

`resolveNovlangPolicy(platform, isSuperuser, forceApple: true)` returns the Apple
policy on every platform, so the Apple vocabulary can be seen on Android. The
superuser stays first: a superuser sees the real words even when the wording is
forced. The app exposes the switch as « Force App Store wording » in App
Settings, only while Dev Mode is on (a local preference owned by the settings
feature).
