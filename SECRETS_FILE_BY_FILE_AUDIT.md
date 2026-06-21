# `secrets` — Full File-by-File Audit (2026-06-21)

Every file in `packages/primitives`, `packages/secrets`, and the two new
`bull_ui` bricks was read and reviewed by an independent reviewer (6 parallel
passes: primitives+bull_ui, domain+VOs, storage+data, crypto, ui+barrel+locator,
tests). This records the per-file verdict and the fixes applied as a result.

Status after this audit: **101 unit tests green**, `flutter analyze --fatal-infos`
clean across the whole project (pre-commit-hook enforced).

## Legend
✅ clean · 🟢 fixed this pass · 🟠 residual (documented) · ⚪ accepted by design

---

## packages/primitives

| File | Verdict |
|---|---|
| `primitives.dart` | ✅ barrel, alphabetized, accurate doc |
| `failure.dart` | ✅ matches #1895 shape exactly |
| `result.dart` | ✅ sealed `Result`, `Ok.value`/`Err.failure`, only `fold`/`map`/`mapErr` — no forbidden extras |
| `fingerprint.dart` | ✅ regex `^[0-9a-f]{8}$`, `tryParse`/throwing split, equality all correct |
| `network.dart` | ✅ coin types (0/1/1776) correct. ⚪ `fromName` throws on unknown (verbatim port; only fed known-good names) |
| `script_type.dart` | ✅ purposes 84/49/44. ⚪ `fromExtendedPublicKey` is mainnet-prefix-only + throws `RangeError` on <4-char input (verbatim port; flagged for the consumer-migration phase) |
| `xpub_type.dart` | ✅ all 6 SLIP-132 version bytes correct, `getXpubType` mapping exhaustive |

## packages/bull_ui (new bricks)

| File | Verdict |
|---|---|
| `bull_mnemonic_grid.dart` | ✅ dumb/presentational, theme tokens, odd-count column math safe, no overflow |
| `bull_seed_warning_card.dart` | ✅ dumb, l10n-agnostic, `Expanded` prevents overflow |

## packages/secrets — domain + value objects

| File | Verdict |
|---|---|
| `secrets_failure.dart` | ✅ sealed; locked≠not-found kept distinct & documented |
| `log_sanitizer.dart` | 🟢 **mnemonic regex hardened** — now case-insensitive + tolerates comma/newline/multi-space separators (was missing capitalized/punctuated phrases — a real leak); xprv/hex anchoring already correct |
| `seed_index.dart` | ⚪ injected app-side port — intentionally not `@useResult`/`Result`-typed (non-secret infra; `SeedRepository` wraps it) |
| `seed_repository.dart`, `key_derivation_port.dart`, `signer_port.dart`, `swap_signer_port.dart`, `backup_vault_port.dart`, `bip85_port.dart` | ✅ all `@useResult`, return `Result<_,SecretsFailure>`, input-only secrets / output-only non-secret |
| `value_objects/seed_info.dart`, `mnemonic_length.dart`, `descriptors.dart`, `psbt.dart`, `created_swap.dart` | ✅ non-secret, validated, no leak |
| `value_objects/bip85_types.dart` | ✅ `words`/`hexForView` `@internal`, redacted `toString`, no `toJson` |
| `value_objects/ark_secret.dart` | ✅ gold-standard: `@internal` bytes, copy-in/copy-out, redacted `toString` |
| `value_objects/backup.dart` | 🟢 **`BackupKey.bytes` now returns a defensive copy** (was an exposed mutable buffer — in-place mutation could corrupt the vault key) |
| `value_objects/signing_intent.dart` | ✅ sealed, no secret fields |

## packages/secrets — storage + data

| File | Verdict |
|---|---|
| `storage/secret_store.dart`, `storage/secure_key_value_store.dart` | ✅ clean, well-documented contracts |
| `data/datasources/keychain_locked_exception.dart` | 🟢 (prior pass) bare `'keystore'` needle removed → no longer misclassifies corrupt entries as locked |
| `data/datasources/secret_not_found_exception.dart` | ✅ both typed as `Exception` (not `Error`) so they map to failures |
| `data/datasources/flutter_secure_storage_adapter.dart` | ✅ `resetOnError:false`, `AfterFirstUnlockThisDeviceOnly`, valid cipher enums |
| `data/datasources/fss_secret_store.dart` | ✅ backoff/locked-rethrow/throw-on-duplicate correct. 🟠 legacy non-base64 blobs would `FormatException` on read (legacy migration is commit 11, not in scope); `keys()` uses `readAll` (transient decrypt of all values — inherent to the port surface) |
| `data/models/seed_secret.dart` | 🟢 **malformed/legacy/unknown-language input now surfaces as `FormatException`** (catchable Exception) instead of a `dart:core` `Error` that escaped `_guard`; unknown language falls back to english |
| `data/seed_reconciler.dart` | ✅ orphan/dangling logic + legacy raw-fp parsing correct & crash-safe. 🟠 a malformed `seed_`-prefixed key is silently dropped (extremely unlikely; consider a debug log) |
| `data/seed_repository_impl.dart` | ✅ `_guard` catch ordering correct, sanitized, concurrent-import race → `DuplicateSeedFailure` (prior fix verified) |

## packages/secrets — crypto

| File | Verdict |
|---|---|
| `crypto/bip32_derivation.dart` | ✅ fingerprint/xprv/testnet-bytes/xpub-convert correct |
| `crypto/bip85_derivation.dart` | 🟢 **`clearRecoverbullPath` anchored** (was global `replaceAll` → could strip a `1608` appearing as a later path element and derive a wrong key) |
| `crypto/descriptor_derivation.dart` | ✅ network mapping correct (native, integration-tier) |
| `crypto/intent_validation.dart` | ✅ (prior fixes verified) send multiset-match, payjoin fail-closed, swap fail-closed when no reconstruction fn. 🟠 send does not validate **inputs** (`SendIntent` has no input field — coin-control/privacy gap, bounded by the output+fee gate) |
| `crypto/key_derivation_port_impl.dart` | ✅ network selection + exception funneling correct |
| `crypto/bip85_port_impl.dart` | 🟢 **`deriveHex` path label now includes `numBytes`** (`128169'/{n}'/{index}'`) |
| `crypto/backup_vault_port_impl.dart` | ✅ encrypt→restore round-trip + duplicate-on-restore correct |
| `crypto/signer_port_impl.dart` | ✅ (prior fix verified) duplicate `lwk.Wallet.init` removed; `trustWitnessUtxo:false`; intent validated before bitcoin sign; temp-dir `finally` cleanup on all paths. 🟠 **`signLiquidPset` performs no PSET intent validation** (LWK exposes no decoded facts like BDK) — documented residual; the method accepts an `intent` it does not enforce for Liquid sends |

## packages/secrets — ui + barrel + locator

| File | Verdict |
|---|---|
| `secrets.dart` (barrel) | ✅ exports only the public surface; no `src/`, `SecretStore`, `SeedSecret`, `MnemonicReader`, `*Impl`. Secret-bearing payloads (`Bip85Derivation`/`Bip85HexResult`) cross only with `@internal` accessors — seal rests on the `invalid_use_of_internal_member` lint in consumer builds |
| `locator.dart` | 🟢 **added a fail-fast `assert(isRegistered<SeedIndex>())`** (was a deferred runtime throw). ⚪ `SecretStore.init()` never called (no-op for FSS; relevant only to a future hardware backend) |
| `ui/mnemonic_reader.dart` | ✅ internal, never exported; error propagation correct |
| `ui/privacy_guard.dart` | ✅ (prior fix verified) ref-counted global `no_screenshot`; single-isolate so race-free |
| `ui/widgets/mnemonic_view.dart` | 🟢 **locator-lookup failure now routed to the warning card** (was a hard `initState` crash). 🟠 no `didUpdateWidget` (a changed `seed` shows stale words — low; one-shot screens) |
| `ui/widgets/verify_backup_view.dart` | 🟢 **added deselect/retry + a `_done` guard so `onResult` fires exactly once** (was no retry path; exactly-once was incidental) |
| `ui/widgets/bip85_mnemonic_view.dart` | ✅ redacted diagnostics, ExcludeSemantics |
| `ui/widgets/bip85_hex_view.dart` | ⚪ `SelectableText` of the hex is a clipboard egress — kept deliberately (a derived hex key is meant to be copyable); flagged for a future guarded-copy affordance |

## Test suite — strengthened this pass

- KATs turned from **shape → exact value**: BIP32 fingerprint now pinned
  (`3f635a63`), child mnemonic pinned to its 12 frozen words.
- **passphrase changes the fingerprint** (BIP39) — now tested (`3f635a63` vs
  `3430baf0`).
- **VerifyBackupView wrong-order** now tested with a distinct-word seed (the
  all-`zoo` positive test alone was near-vacuous).
- `DuplicateSeedFailure.fingerprint`, `isA<SecretsFailure>`,
  `BitcoinDescriptor`/`LiquidDescriptor` empty-rejection, `BackupKey` >32,
  `SeedSecret.fromStorageBytes` malformed→`FormatException` + round-trips,
  uppercase-hex / capitalized-comma-phrase / tprv sanitizer cases — all added.

## No-defer pass — additions audited (2026-06-21, fresh adversarial reviewers)

New code (SwapSignerPort impl, Liquid/input validation, hardening) was itself
audited by fresh reviewers. Two findings, both fixed + tested:

- 🔴 **`createChainSwap` was broken + under-validated** — it checked both keys
  against `btcScriptStr` only, so every chain swap was rejected AND the
  `lbtcScriptStr` leg was never validated. Fixed: extracted a pure
  `IntentValidator.validateChainSwapCommitment` that routes lockup/claim legs
  per `ChainDirection` and validates BOTH scripts; unit-tested both directions +
  per-leg tamper rejection. (The reviewer traced the Boltz Rust source and
  confirmed the commitment check is genuinely sound vs a malicious server —
  `swap.keys` are derived locally from our mnemonic, not echoed by Boltz.)
- 🟠 **log_sanitizer over-redacted prose** — the case-insensitive "12+ short
  words" regex blanked ordinary 12-word log sentences. Fixed: now matches only
  runs of ≥12 **adjacent BIP39 wordlist words**, so a real phrase (even
  capitalized/embedded) is redacted but prose stays readable; tested both ways.
- 🟡 (noted) `seal_check.sh` doesn't scan repo-root `test/` and misses a
  bare `export 'src/ui/...'` without a `show` clause — both still caught by the
  primary `implementation_imports` lint; left as belt-and-suspenders.

## Remaining residuals (unchanged from SECRETS_IMPLEMENTATION_AUDIT.md)

The dominant gaps are **untested native paths**, not logic defects:
`SignerPortImpl` / `KeyDerivationPortImpl` / `DescriptorDerivation` / the
`SwapSignerPort` impl exercise bdk/lwk/boltz FFI and are integration-tier (need
a device/testnet) — the pure decision logic they call (`IntentValidator`, BIP85
KATs) IS tested. Plus the spec-level residuals: consumer migration (F1), the
`secrets_lint` plugin + CI gates (F2), Liquid PSET intent validation (F6), and
the LWK temp-db orphan-sweep (F7). Recommended order: F2 → native integration
tests → F1 (staged).
