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

## 9. Fresh end-to-end audit (5 independent agents) — findings + dispositions

A second, fully-independent audit (data-loss, signing, seal, crypto/supply-chain,
architecture/consequences). Real findings, **FIXED**:
- 🔴 **Legacy OldSeed passphrase bug** — the decoder I added guessed a passphrase
  from the OldSeed `passphrases` list; for a multi-passphrase seed that derives a
  DIFFERENT fingerprint than the storage key → unfindable seed. Fixed: the raw-fp
  OldSeed key is the BARE-mnemonic fingerprint, so it now decodes as the bare
  mnemonic (no passphrase guess); fingerprint==key proven by test.
- 🔴 **Log-sanitizer one-typo leak** — a 12-word phrase with one mistyped word
  left the other 11 (brute-forceable) words un-redacted. Fixed: redact a ≥12-token
  span with ≤2 non-BIP39 inside (typo-tolerant); prose stays readable; tested.
- 🟠 **`purge()` wiped the whole shared keychain** (incl. app-owned `swap_*`/PIN/
  hive). Fixed: scoped to the seed keys this store owns; tested.
- 🟠 **Release-stripped `assert`** in the locator → runtime `StateError`.
- 🟡 Bitcoin fee BigInt/u64 range guard; `hiveEncryptionKey` constant; transient-
  read retry parity; native-test `@Tags(['native'])`; seal-check `part`-ban;
  payjoin integration note.

**Documented residuals (cannot be fully closed in-package — integration work):**
- ✅ **fss9 / EncryptedSharedPreferences cohort — RESOLVED (see §13).** The app's
  storage migration standardized every install on fss10 (verified `SeedStoreType`
  flag); the package's fss10-only `.standard()` adapter is therefore correct for
  every user. The fss9/ESP path survives in the app only as a transitional
  fallback. No dual/migrating backend is needed in the package.
- 🔴 **Liquid send validates fee only** (confidential outputs unprovable) — known.
- 🟠 **Native bdk/lwk/boltz signing/swap execution is unit-untested** — needs a
  device/testnet integration suite before production trust.
- 🟠 **Supply chain:** `bull_sdk` rides a moving `main`/`ws-resilience` ref and
  `bdk_dart` is a personal-account fork (both SHA-resolved via the lockfile today);
  pin repo-wide before production.
- 🟠 **F1 consumer migration** (app wiring, the startup `reconcileSeeds` call +
  self-heal, the run-005-first / never-purge orchestration) is app-side, unbuilt.
- 🟡 KATs are self-generated regression anchors — add one published BIP85 spec
  vector; l10n failure→string mapping is planned but unbuilt; per-adapter
  "unexpected" failures collapse into `Signing/Vault/Unexpected` (UX/triage).

## 8. User-data migration safety (3 fresh audit agents, post-refactor)

Three fresh agents audited the whole branch with a focus on **not losing
existing users' funds** when the app adopts the package. The critical finding
(confirmed by a concrete trace): the new on-disk format
(`s1:`+base64(`{kind,words,…}`)) is **incompatible** with what the live app has
written (`{"mnemonicWords":[…],"runtimeType":"mnemonic"}`, no prefix) — a naive
swap would make **every existing seed unreadable** → destructive-recovery / fund
loss. The fingerprint derivation is byte-identical old↔new (proven), so keys
align *once the decoder can read the payload*.

**FIXED:** `Mnemonic.fromStorageBytes` is now **backward-compatible** — it reads
(1) this package's `kind`/`words` format, (2) the current app's
`runtimeType`/`mnemonicWords` SeedModel JSON, and (3) the pre-0.4 OldSeed
`{"mnemonic":"word word …","passphrases":[…]}` shape; a bytes-only seed is
explicitly + safely rejected (never silently lost). A 9-test migration suite
(`test/migration/legacy_format_test.dart`) writes the **exact historical on-disk
JSON** and proves words/passphrase are recovered AND the derived fingerprint
equals the storage key (12/24-word, passphrase, legacy, and the sealed
`MnemonicReader` display path).

**STILL APP-SIDE (F1, not the package):** wiring the package in must (a) run the
existing 004/005 migrations first, (b) have the reconciler self-heal a
found-but-unindexed seed by upserting `SeedInfo` (never treat readable-but-
unindexed as "missing → recover"), and (c) NEVER call `SecretStorePort.purge()`
during migration (it wipes all keys, incl. app-owned `swap_*`/PIN). Per spec G1,
`swap_*` per-swap KeyPairs stay app-managed. A device-level `integration_test`
against real `flutter_secure_storage` is the final belt-and-suspenders proof;
the in-package suite already covers the decode + fingerprint-alignment risk.

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

---

## §10 — Round-3 fresh audit (3 independent agents) + fixes

Third full audit (verify-latest-fixes / codebase-consequences / independent
security sweep). The package's seal, signing gate, migration decode, and
fail-closed behavior were independently re-confirmed sound. Fixed findings:

1. **log_sanitizer spread-typo seed leak (MED→fixed).** The old
   `(span - bip39count) <= 2` cap was a fixed typo budget; 3 *isolated* typos
   never break the adjacency run yet blow the budget, leaving all real BIP39
   words in cleartext. Reproduced a 12-word phrase leaking. Replaced with a
   COUNT-based trigger (`bip39count >= 12 || (bip39count >= 9 && density>=75%)`)
   so any number of spread typos can't expose the words. +2 regression tests.
2. **seal_check FSS allow-list bypassable by filename (LOW→fixed).** Unanchored,
   unescaped `grep -vE` let `…storage_locator.dart.bak.dart` slip through.
   Switched to exact whole-line matching (`grep -vxF`). Verified the bypass is
   now caught.
3. **seal_check comment contradicted decision G1 (doc→fixed).** Comment claimed
   the 3 grandfathered app files "shrink to just the adapter" after F1; G1 keeps
   swap/PIN/api-key on the shared keychain, so the live storage layer keeps
   keychain access permanently. Comment corrected; the enforceable invariant is
   "raw plugin confined to the adapter + live storage layer; the SEED is owned
   only by secrets."
4. **Bip85HexView clipboard sink (LOW→fixed).** `SelectableText` exposed the
   derived hex secret to the clipboard (uncovered by PrivacyGuard). Switched to
   non-selectable `BullText`, matching the mnemonic views.

**Residuals (unchanged, documented):** sanitizer doesn't redact base64 blobs
(a blanket base64 redactor would over-redact legit logs; realistic leak bounded
to <12 partial words via FormatException echo); `Psbt._isBase64` shallow
(non-secret, bdk/lwk re-parse). **F1 integration consequences** (not package
bugs — consumer-migration scope, already in MIGRATION_PLAN): ~~the package needs a
real dual-backend / migrating `SecretStorePort` for the fss9/ESP cohort~~
(SUPERSEDED — see §13: the app is fss10-universal, `.standard()` is correct for
all users); the app must ship a Drift
`seed_index` table + backfill before wiring `SeedIndexPort`; ~58 seed-consuming
call sites move to ports. State: 137 secrets + 25 primitives tests green,
analyze clean, seal-check (incl. FSS gate) passes.

---

## §11 — Codebase-wide audit + impact vs develop (4 fresh agents) + fixes

Full file-by-file audit of the whole branch and its impact on `develop`. Scope
confirmed **additive & surgical**: outside the new packages, the branch touches
only 4 existing files — root `pubspec.yaml` (2 workspace members), `makefile`
(`seal-check` target), `.github/workflows/analyze_and_test.yml` (CI step),
`packages/bull_ui/lib/bull_ui.dart` (2 brick exports).

**Impact verdict: does NOT break develop.** `fvm flutter pub get` at root
resolves clean with NO lockfile delta vs develop (new packages use
`resolution: workspace`, `^3.10.0` SDK satisfied by the root `3.12.2`, git refs
governed by the existing root `dependency_overrides`). CI step has no
`|| true`/`continue-on-error` so a seal breach correctly fails the build.

Fixes applied this round:
1. **primitives `Network.fromName` / `ScriptType.fromName`** threw a bare
   `StateError` on unknown input (inconsistent with the package's `ArgumentError`
   convention). Added `orElse: throw ArgumentError.value(...)` + tests for both
   throwing factories (the gap that hid this).
2. **bull_ui `BullMnemonicGrid`** index column was a fixed `SizedBox(width:28)`
   that could clip 2-digit indices (10–24) at large text scale. Switched to
   `ConstrainedBox(minWidth:28)` (grows instead of clipping) + a 12-word test
   covering the 2-digit path and end-of-list numbering.
3. **bull_ui barrel** A–Z order broken (`seed_warning_card` before `price_card`).
   Re-sorted.
4. **secrets `bip32_derivation.xprvFromSeed`** testnet `NetworkType.wif` was the
   mainnet byte `0x80`; corrected to testnet `0xEF`. Latent (only `toBase58()`/
   xprv is used, so no output changed) but now correct for any future WIF export.

**Reported, not fixed (out of scope / pre-existing):** the root
`dependency_overrides` pins `bull_sdk`/`boltz_stream` to a moving branch ref
(`ws-resilience`), not a SHA — a pre-existing repo-wide supply-chain item on
develop, not introduced by this branch; recommend SHA-pinning repo-wide
separately. Cosmetic-only items left as-is: `Bip85HexResult.path` label is a
reconstructed display string (bytes correct); `BullSeedWarningCard` uses a
filled panel vs siblings' accent-bar (design choice).

State: primitives 27 + secrets 137 tests + bull_ui suite green, `analyze` clean
in all three packages, seal-check passes, root `pub get` clean.

---

## §12 — Security audit (before/after gains) + hardening, no-defer round (4 fresh agents)

Deep before/after security audit comparing the app's CURRENT secret handling on
`develop` to the `secrets` package, then fixed every package-scope item that is
buildable now. NOTE the package is still DORMANT (the app imports nothing yet:
`grep -r "package:secrets" lib/` is empty), so the gains below are realized once
the app is wired (F1) — but the *posture* is now in place.

### Security GAINS vs the "before" baseline (top 5)
1. **#1703 intent gate / fail-closed signing** vs today's BLIND signing of BTC
   PSBT (`bdk_wallet_datasource` with `trustWitnessUtxo:true`), Liquid PSET,
   payjoin and swaps.
2. **`trustWitnessUtxo:false`** vs the live `true` (SegWit fee-inflation footgun).
3. **Log sanitizer + redacted `toString`/no-`toJson` VOs** vs the live path where
   freezed `SeedModel.toString()`/`toJson()` + an unredacting `logger.dart` can
   ship a raw mnemonic to disk/Sentry.
4. **SecretGuard single read chokepoint + library-private seal** vs ~15 direct
   raw-seed reads scattered across 9 app features today.
5. **Untrusted-Boltz-address swap commitment proof** vs trusting the server's
   address.
(Already-good on develop: locked≠missing handling; no keychain `deleteAll` wipe.)

### Hardening applied this round (all buildable in-package now)
1. **Swap locktime binding** (HIGH): `SwapIntent.timeout` existed but was NEVER
   validated. Added `SwapScriptLeg.locktime` + an opt-in (`expectedLocktime>0`)
   equality check in `validateSwapCommitment`; the chain validator binds the
   LOCKUP leg (our funds) to the intent timeout, not the claim leg (differs per
   chain). Threaded `Btc/LBtcSwapScriptStr.locktime` from the adapter. +4 tests.
2. **LiquidDescriptor privacy leak** (A1): the ct descriptor embeds the master
   blinding key; `toString()` printed it in full and it was mislabeled
   "NON-secret". Redacted `toString` + corrected the doc. +1 test.
3. **Sealed-blob log redaction**: `sanitizeLog` now redacts the at-rest
   `s1:`+base64 blob (anchored on the `s1:` tag → no over-redaction of ordinary
   base64). +2 tests.
4. **Constant-time backup-verify**: removed the early-break word compare in
   `verify_backup_view` (visit every word; OR a mismatch flag).
5. **Independent KAT vectors**: added official BIP39 (TREZOR) seed + BIP32 vector
   1 (fingerprint `3442193e` + master xprv) cross-checks — catches a
   systematically-wrong derivation that self-frozen vectors cannot. PASS.
6. **Migration test gaps**: added case-1 (`kind:mnemonic`) fingerprint==key and
   a bytes-vs-mnemonic precedence test.

### Genuinely deferred (cannot be done safely in-package now — honest)
- **Liquid confidential output validation** (HIGH-1): Liquid sends remain fee-cap
  only. Per-output/recipient/change validation needs the blinding keys to unblind
  outputs — only available in the app's LWK wallet context, not to the pure
  validator. A fragile/incorrect check would be worse than the documented limit;
  it must be done when wired, with the wallet's blinding data.
- **Dual fss9/ESP backend**: NO LONGER NEEDED (see §13) — the app is
  fss10-universal post-migration, so the package's fss10-only `.standard()` is
  correct for every user. Dropped from the work list.
- **Swap amount/out-address binding** (MED): server-computed amount semantics
  differ per swap type; binding needs the app's expected-value context to avoid
  rejecting valid swaps.
- **Secret zeroization**: Dart can't guarantee (GC + immutable String words);
  best-effort `fillRange` on transient buffers offers little and risks clearing
  still-referenced data — left as a documented platform limitation.
- **Vault HMAC/enc key separation** (MED-5): lives in the pinned `recoverbull`
  dep, not in `secrets` (upstream fix).
- **bull_sdk moving git ref**: pre-existing repo-wide override, not this branch.

State: 147 secrets + 27 primitives tests green, analyze clean, seal-check passes.

---

## §13 — fss10 is now universal: dual-backend concern resolved

User confirmation: since the recent storage update, every install is on fss10 by
default. Verified against `lib/core/storage/storage_locator.dart` — startup
probes fss10, then verifies and persists a fss10 `SeedStoreType` flag; the
fss9/ESP (`flutter_secure_storage_legacy`) branch remains only as a transitional
fallback for a not-yet-migrated install.

Consequence: the package's fss10-only `FlutterSecureStorageAdapter.standard()`
is correct for EVERY user. The previously-flagged "dual / migrating
`SecretStorePort` for the fss9/ESP cohort" (prior §8 🔴, §11, §12) is **no longer
needed and is dropped from the work list**. The `.standard()` factory comment was
rewritten from a fund-loss DATA-MIGRATION warning to an accurate note (fss10 is
universal; inject a custom backend only for the unlikely not-yet-migrated case).
No package code changed beyond the comment — the dual backend was only ever
documented as deferred, never built, so there is no dead code to remove.

The remaining genuine residual on the storage axis is none; the open
integration items are unchanged (Drift `seed_index` + backfill, ~58 call-site
rewires, Liquid confidential-output validation — all F1/app scope).
