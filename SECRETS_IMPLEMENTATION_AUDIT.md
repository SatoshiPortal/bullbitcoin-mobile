# `secrets` — Implementation Audit (post-build, 2026-06-21)

Audit of the code actually built in this session (branch `refactor-secrets`),
against the threats in [SECRETS_SECURITY_AUDIT.md](SECRETS_SECURITY_AUDIT.md)
(A–H) and the gates in [SECRETS_REFACTORING_SPEC.md](SECRETS_REFACTORING_SPEC.md) §9.

## 0. What was built (scope delivered)

Two new workspace packages, **additive** (the live app is untouched and does not
yet import them):

| Package | Status | Tests |
|---|---|---|
| `packages/primitives` | complete | 22 ✓ |
| `packages/secrets` (43 lib files, ~2.7k LOC) | core complete; native exec untested | 76 ✓ |
| `packages/bull_ui` (3 new bricks) | complete | ✓ |

Green: `flutter analyze --fatal-infos` clean across the whole project (enforced
by the pre-commit hook); `primitives` + `secrets` + `bull_ui` unit suites pass.

Delivered, with tests: `Result/Failure/Fingerprint/Network/ScriptType/XpubType`;
`SecretsFailure` family + boundary log sanitizer; all value objects;
`SecretStore`/`FssSecretStore`/`SeedIndex`/reconciler; BIP32/BIP85/recoverbull/ARK
crypto (KAT byte-exact); `SeedRepository`; `KeyDerivationPort`; `Bip85Port`;
`BackupVaultPort` (round-trip); `SignerPort` (+ `IntentValidator`, the #1703 gate);
the 4 sealed widgets; barrel + `SecretsLocator`.

## 1. Seal integrity — VERIFIED

- **Barrel exports nothing internal.** `lib/secrets.dart` is `show`-listed; no
  `src/crypto`, `SecretStore`, `SecureKeyValueStore`, `SeedSecret`,
  `MnemonicReader`, or `*Impl` is exported (grep-confirmed).
- **Cross-package `src/` reach-in is lint-fatal.** The root analysis options
  include `package:lints/recommended` → `implementation_imports` fires on
  `import 'package:secrets/src/...'` from the app, and CI runs `--fatal-infos`.
  So the hard wall (library-privacy + non-export) is backed by a real lint even
  though the bespoke `secrets_lint` plugin (commit 2) is **not** built yet (§3).
- **Secret-bearing exported types** (`Bip85Derivation.words`,
  `Bip85HexResult.hexForView`, `ArkSecret.bytes`) expose their secret ONLY via
  `@internal` accessors; redacted `toString`; no `toJson`. The internal
  `SeedSecret`/`MnemonicSeedSecret` getters are plain (acceptable — the type is
  never exported).
- **Redacted diagnostics test** (`seal_widget_test`) proves `MnemonicView`'s
  `debugFillProperties` emits the fingerprint, never the words.

## 2. Threat-by-threat

- **A2/A4 memory hygiene (PARTIAL).** Redacted `toString`, no `toJson`, sanitized
  `logMessage` at all 5 boundaries (grep-confirmed). **Gap:** PBKDF2/BIP32/BIP85
  derivation runs synchronously on the main isolate, not in a bytes-only
  `compute()` isolate (audit A4). In-Dart heap exposure is unavoidable (Dart
  can't zeroize; moving GC) — this is the accepted SPEC §10 residual, but the
  isolate-hygiene optimization the live app has (`compute`) was not reproduced.
- **A3 log sanitization — DONE + TESTED.** `sanitizeLog` redacts 64-hex,
  xprv/tprv base58, and 12/24-word phrases; applied before every failure is
  constructed; 7 tests.
- **B seal bypass — see §1.** Hard wall in place; bespoke lint layer pending.
- **#1703 blind signing — CLOSED + TESTED (headline).** `IntentValidator` is a
  pure, fully-tested gate: send fee-cap + change-ownership, BIP78 payjoin
  checklist (version/locktime/inputs/outputs/fee), swap redeem-script/lockup
  address assertion. 13 tests exercise every tampered-tx rejection path.
  `SignerPort` calls it BEFORE `wallet.sign` and uses `trustWitnessUtxo:false`.
- **E storage — DONE.** `FssSecretStore` sets `resetOnError:false` (fork
  seed-wipe footgun), `AfterFirstUnlockThisDeviceOnly`, rethrows
  `KeychainLockedException` (never collapses to not-found — distinct failure
  variant, tested), 5-attempt backoff, legacy-key enumeration + reconciler
  (orphan/dangling detection, tested).

## 3. Findings (ranked)

🔴 **F1 — Consumer migration NOT done (the dominant scope boundary).** Commits
4/5/7/9/10/11/12 (app-side rewiring: `CreateDefaultWalletsUsecase`, `WalletModel`
split, 8 secret-consumer families, Drift `seed_index` v13→14, legacy-secret
purge, `core_locator` swap, docs) are **not** implemented. Therefore SPEC §9.6
**gate (a)** holds (the package's *own* public API leaks no secret at every
commit) but **gate (b)** — "no mnemonic crosses ANY app code", which only lands
at commit 10 — is **not** achieved. The app still uses its own seed paths.

🔴 **F2 — `secrets_lint` plugin + CI gates NOT built (commit 2).** The
`useAndForget` allow-list, `part of`-into-secrets ban, and suppressed-diagnostic
/ ref-SHA / CODEOWNERS CI gates are absent. Partial mitigation: built-in
`implementation_imports` (fatal) blocks app→`src/` imports (§1).

🟠 **F3 — `useAndForget` allow-list violation.** `src/ui/mnemonic_reader.dart`
calls `useAndForget`, but the spec's allow-list is `src/crypto/*` only. The
widgets legitimately need to read the mnemonic, so the allow-list must be
extended to include the reader (or the reader moved under `src/crypto`). Benign
today (lint not built), but must be reconciled before F2 lands.

🟠 **F4 — Native signing/swap paths untested.** `SignerPort` (bdk in-memory /
lwk temp-db) and `BackupVaultPort` compile against the verified bdk/lwk/recoverbull
APIs and `BackupVaultPort` round-trips in a pure-Dart test, but bdk/lwk FFI
execution needs a device → the testnet integration tests (SPEC §9.5: happy +
tampered-PSBT-rejected, create/claim/refund swap) are **not** run here. The
*decision* logic (`IntentValidator`) is fully tested; the *extraction* (PSBT→facts)
is not.

🟠 **F5 — `SwapSignerPort` is interface-only.** No concrete impl (the Boltz SDK
is network-config-coupled and its redeem-script types are unverifiable for a
*testable* build here). Wiring is deferred to commit 10; the security property
it must enforce is already covered by `IntentValidator.validateSwap`.

🟡 **F6 — Liquid PSET intent validation gap.** `signLiquidPset` does not extract
PSET facts to validate send/payjoin intents (LWK exposes no decoded view like
BDK). Swap intents are asserted at creation. Documented inline + SPEC §10.

🟡 **F7 — Liquid temp-db orphan-sweep missing.** `signLiquidPset` writes an
ephemeral LWK db to `Directory.systemTemp` and deletes it in `finally`, but the
best-effort orphan-sweep at signer init (SPEC §10) is not implemented — a kill
mid-sign leaks the temp db (not crash-safe). Also: `systemTemp` may not be the
most-protected path on every OS; prefer an app-private cache when wired in-app.

🟡 **F8 — Storage format differs from legacy.** `FssSecretStore` persists
`base64(utf8(json{words|bytes}))`; the live app stores `seed_<fp> →
jsonEncode(SeedModel)`. The new package cannot read existing seeds until the
commit-11 legacy migration bridges them. No impact while additive.

🟡 **F9 — `ArkSecret` export vs `@internal` bytes.** `ArkSecret` is exported but
its `bytes` are `@internal`, so an app consumer can hold one but not use it
without tripping the lint. Either ARK-node construction must stay in-package or
`bytes` must be public. Matches the spec's ARK ambiguity (dev-mode, deferred).

🟢 **F10 — freezed deviation (accepted).** VOs are hand-written immutable classes,
not freezed. Deliberate: freezed's generated `toString` prints every field (a
leak vector for secret-bearing types) and `toJson` is exactly what the audit
bans; hand-writing gives full redaction control and removes the experimental
`build_runner --workspace` dependency. More secure, not less.

🟢 **F11 — `store()` TOCTOU.** `containsKey`-then-`write` is a benign race in
single-threaded Dart with per-seed flow; left as-is.

## 4. Verdict

The **security-critical, self-contained core is built, sealed, and tested**: the
seal holds at the package boundary, the #1703 intent gate is closed and
exhaustively tested, KAT vectors match byte-for-byte, and storage hardening
(resetOnError, locked-rethrow, reconciliation) is in place. The **dominant
residual risk is unchanged from the spec's own honest framing**: this is the
foundation, not the whole 12-commit PR — the high-blast-radius **consumer
migration (F1) and the bespoke lint/CI layer (F2) are not done**, and **native
signing/swap execution is unverified (F4/F5)**. Recommended next steps, in order:
F2 (lint+CI, cheap, locks the seal), F4 (testnet integration), then F1 (staged
per the repo's incremental norm rather than one blind cut).

## 5. Post-review fixes (high-effort code review, same session)

A high-effort review of the diff surfaced 10 findings; the 7 confirmed
high/medium correctness+security bugs were FIXED (commit `a29fceaa`, +10 tests):

1. **Keychain mis-detection (🔴):** dropped the over-broad `'keystore'` needle
   that classified a corrupt/missing Keystore entry as "locked" (would hide a
   real loss behind endless retry).
2. **`PrivacyGuard` capture-block leak (🔴):** ref-counted the global
   `no_screenshot` singleton so a nested guard's `dispose` can't re-enable
   capture while another secret is still shown.
3. **`SendIntent` validation holes (🔴):** switched from Set-membership to
   multiset matching — now rejects a duplicated recipient (2× pay) and a missing
   declared output.
4. **Payjoin fail-open (🟠):** version/locktime now FAIL CLOSED on null facts.
5. **Double `lwk.Wallet.init` (🟠):** removed the duplicate temp-db open.
6. **Sealed-view infinite spinner (🟠):** `MnemonicView`/`VerifyBackupView` now
   surface a warning on read error / bytes-only seed instead of hanging.
7. **Concurrent-import crash (🟠):** `store()` throws a typed
   `SecretAlreadyExistsException` → mapped to `DuplicateSeedFailure`, not a crash.

## 6. No-defer resolution pass (same session)

A subsequent "fix everything, defer nothing" pass resolved the remaining
package-level residuals (the earlier doc's F4/F5/F6 and the file-by-file 🟠s):

- **F5 — `SwapSignerPort` implemented** (`SwapSignerPortImpl`): wraps Boltz
  BtcLn/LbtcLn/Chain creation, reads the mnemonic via `useAndForget`, and
  asserts the returned swap script commits to OUR derived key + the intent's
  preimage hash (`validateSwapCommitment`, own-claim/own-refund per direction).
  Registered in the locator. Commitment logic unit-tested (reverse/submarine/
  chain, tamper-rejected); Boltz network execution remains integration-tier.
- **F6 — Liquid intent validation added** to `signLiquidPset`: sound fee-cap
  check (`LiquidTransaction.fromPset().fee()`; fee is unblinded) + refuses a
  `SwapIntent` on the generic path. Confidential per-output change-ownership is
  not provable on blinded outputs (no false guarantee) — the one remaining
  honest residual here.
- **F4 — native bdk path now tested**: bdk's FFI lib loads under `flutter test`
  on this host, so `KeyDerivationPort` (accountXpub/bitcoinDescriptor/
  masterFingerprint) is exercised for real (4 native tests). LWK needs SDK
  init under the test host; the Liquid descriptor path stays integration-tier.
- **SendIntent input validation**: every send input must be wallet-owned
  (signer resolves witness + non-witness prev-out scripts, fails closed if any
  is unresolvable) — closes the coin-control / foreign-input vector.
- **F2 (slice) — `make seal-check`**: CI gate for external `src/` imports,
  internal barrel exports, and suppression of `invalid_use_of_internal_member`.
- Storage/widget/primitives hardening: legacy non-base64 decode; reconciler
  surfaces malformed keys; `MnemonicView` `didUpdateWidget` + bytes-only
  warning; primitives `tryFromName` + testnet xpub prefixes.

Result: **119 secrets + 25 primitives tests green**, `analyze --fatal-infos` +
`seal-check` clean. Remaining (genuinely net-new app work, not package fixes):
**F1 consumer migration** (live-app rewiring — staged, separate effort) and the
full first-party analyzer **plugin** (the `seal-check` grep gate covers its
security intent today).

## 7. Cybersecurity-expert review (4 parallel domain auditors)

A dedicated security review across four threat domains (seal/egress, signing &
intent, storage & error lifecycle, crypto & supply-chain). Load-bearing
invariants were confirmed **sound**: the #1703 gate has no blind-sign path; the
swap-commitment check is a *genuine* defense vs a malicious Boltz server
(verified against the Boltz Rust source — our key is mnemonic-derived, not
echoed, and the SDK binds it into the lockup address); chain-swap leg routing is
correct in both directions with the LBTC leg validated; `locked ≠ missing`
holds; no `dart:core Error` escapes the boundary; RNG is `Random.secure`;
derivation/version-bytes/KATs are correct; `resetOnError:false`; the seal has no
code-level egress.

**Findings FIXED this pass:**
- 🔴 **log-sanitizer leak (real):** a JSON-list-formatted phrase
  (`["abandon","ability",…]`) wasn't redacted because `","` broke the adjacency
  rule → broadened the separator class (quotes/brackets/punctuation); tested.
- 🟠 **silent mis-decode:** `_decode` guessed base64-vs-raw and could mis-decode
  a base64-shaped legacy value → new values now carry an `s1:` version tag so
  decode is deterministic; tested.
- 🟠 **seal not CI-enforced:** wired `make seal-check` into the GitHub workflow;
  hardened the script to also scan `test/`, ban internal `src/ui` exports,
  require `show` on every `src/` export, and flag an `analysis_options.yaml`
  downgrade of `invalid_use_of_internal_member`.
- 🟡 **Liquid fee BigInt→int wrap:** a crafted PSET fee could wrap under the cap
  → range-guarded before conversion.
- 🟡 **supply-chain honesty:** corrected the misleading "SHA-pinned" comment
  (`bull_sdk` follows root's moving `main` + ws-resilience override — a
  repo-wide pin is the real follow-up).

**Documented residual (NOT shipped blind — deliberate):**
- **Liquid send validates only the fee, not confidential outputs.** Confidential
  amounts are blinded; sound per-output validation needs wallet-side unblinding
  (`Wallet.decodeTx`) which is native and **cannot be tested under this host's
  `flutter test`** (LWK doesn't load). Shipping unverified validation into a
  fund-signing path is riskier than the bounded, documented fee-cap. This is the
  one item that requires the LWK device/testnet harness to implement safely —
  flagged as the explicit next integration task, not a convenience deferral.
  (Bitcoin signing is fully output/input/fee-gated.)
- Clipboard egress on `Bip85HexView` (`SelectableText`) is an intentional,
  PrivacyGuard-scoped UX choice for a copyable hex key — product sign-off item.
- Android `allowBackup` must be disabled app-side to match iOS device-only (app
  manifest, not this package).

Not fixed (by design / out of scope, noted): repeated-word verify uses
value-equality (correct — identical words are interchangeable; distinct phrases
still require exact order); `clearRecoverbullPath` unanchored replace (faithful
port of the app's existing behavior, ~2⁻³¹ trigger); `Bip85HexView`
`SelectableText` clipboard egress (hex is meant to be copyable — flagged for a
guarded-copy follow-up); `Psbt` base64 check is shallow (bdk rejects at decode).
