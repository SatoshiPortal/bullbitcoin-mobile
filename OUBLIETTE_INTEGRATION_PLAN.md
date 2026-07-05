# Oubliette Integration Plan — Dual Backend, Batch Migration
## `packages/secrets` · `dart-oubliette`

> Date: 2026-06-24 · Author: ethicnology
> Status: decision-locked. **Phase 0 (oubliette `keys()`) ✅ committed & pushed (dart-oubliette `25a4887`). Phase 1 (BULL `packages/secrets` adapters + FSS hardening + `init`/probe wiring + tests) ✅ DONE — `flutter analyze` clean, pointycastle 4 via root override.** Phase 2 (standalone probe + census) is next. Deep-audited across multiple passes (native Swift/Kotlin/C++, dependency graph, adversarial review).
>
> **Post-audit update (2026-07-01):** a 13-expert re-audit + fix pass corrected several items this plan asserts. Current package test count is **220 green** (the "175"/"211" figures below are historical baselines). `make seal-check` — which the new `useAndForget` sites in the oubliette adapters initially broke — was repaired (its allow-list now covers two categories: raw readers + store implementations) and is green. The probe round-trip was sealed into `OublietteSecretStoreAdapter.probeRoundTrip()`. `Secrets.reconcile()` + `ReconcileReport` shipped (startup store↔index heal). The Linux `fl_value_get_string_size` blocker is fixed upstream (see §Phase 0 note). pointycastle 3→4 was verified byte-compatible for the signing/vault consumers (additive release). The §5.4 code sketch predates these; treat the shipped code as authoritative.

---

## 0. Decisions locked

| # | Decision | Consequence |
|---|---|---|
| 1 | Keep `init` (no `setup` rename); add `keys()` to oubliette | `keys()` is a query alongside `exists`; no churn to the verb family |
| 2 | **Probe + census ship first, standalone** | A build that *measures* device compatibility and `log.shout`s it, **without storing any seed in oubliette** — fleet data before any seed risk |
| 3 | **Batch migration (not lazy-per-read)** | One explicit, index-driven, quiesced migration pass per device; each device's outcome `log.shout`'d to Sentry; FSS kept as a safety net; FSS removal is a later, data-driven decision. Eliminates the per-key lock, purge gate, and migrate-on-read |
| 4 | `requireHardwareBacking: false`; incapable devices get **no warning** | Such devices stay FSS-only and are **counted via `log.shout`** (census), but no scary UI |
| 5 | **Oubliette-ready is Phase 0** | First deliverable; the backup story is unchanged (factory reset / new phone → user restores from their own backup, exactly as with FSS). The goal is a *more controlled storage environment*, not new recoverability |

The whole point of #2 + #3: **measure, then migrate with observability, then remove FSS when the Sentry numbers say it's safe.** If some devices fail migration, postpone FSS removal; if none do, bring it forward.

---

## 1. Verified facts (audited against source)

### 1.1 Oubliette concurrency & lifecycle (all three platforms)

| Op | Per-slot lock? | Notes |
|---|---|---|
| `store` | ✅ | put-if-absent; throws `StateError` on duplicate; self-heals the key via `_ensureKey` (Android `:85`) |
| `fetch`/`useAndForget` | ❌ | returns `null` if absent; zeroes the buffer in a `finally` |
| `trash` | ❌ **no lock** (Android `:262`, Darwin `:256`, Linux `:181`) | |
| `exists` | ❌ | |
| `purge` | ✅ profile gate, drains in-flight **writes** | Android deletes the key; Darwin retains the SE key; Linux has none |

`init()` is **not uniform**: Android mints a Keystore key; Darwin is a **no-op** when `secureEnclave:false` (`:82`); Linux **probes** the Secret Service and can throw `BackendUnavailableException` on a headless/locked box (`:79`).

### 1.2 Hardware-backing reality (chosen `evenLocked` / `secureEnclave:false` / `strongBox:false`)

iOS ✅ (Keychain class keys) · Android ✅ (TEE Keystore, minSdk 30) · macOS ❌ (software login keychain) · Linux ❌ (software Secret Service). → **Wire oubliette only on iOS + Android.**

`evenLocked` is immune to `KeyInvalidatedException` (it sets `userAuthenticationRequired:false`, so biometric re-enrollment / lock-screen changes don't kill the key). The only residual key-loss path is Android Auto Backup restore — and **BULL already sets `android:allowBackup="false"`** (AndroidManifest.xml:51); it must stay false.

### 1.3 Existing app mechanisms to reuse

- **`SeedStorageLibrary { fss10, fss9, // oubliette }`** — a device-wide flag persisted by `SeedStoreTypeDatasource` under the SharedPreferences key `seed_store_type` (`{"storageLibrary":"fss10"}`). Enum serializes by `.name`.
- **`StorageLocator`** — already does "try a backend → probe via `readAll()` → on success commit the flag, else fall back → commit the fallback flag," narrated with `log.fine/warning/severe`. Oubliette slots in *ahead* of fss10.
- **`log.shout({required message, error, trace, category})`** — consent-gated, awaitable; routes to Sentry (`SentryLevel.info` message, or `captureException` when `error` is set) + the on-disk TSV. `ReportCategory { migration, error }`.
- **Install-vs-upgrade census** — `Report.migrationType` (null fromVersion→install, differing→upgrade) → `await log.shout(message: type.name, category: ReportCategory.migration)` → `Report.commitVersion()` **after** the shout, so a crash retries the event. The oubliette census mirrors this shape exactly.

### 1.4 `SecretStorePort` (the seam, "oubliette parity")

`init` · `store(k, bytes)` (throws if exists) · `useAndForget<R>(k, fn)` (throws `SecretNotFoundException` if absent) · `exists` · `trash` · `purge` · `keys()` · `capabilities()`. Sole impl today: `FssSecretStoreAdapter`. The package is **pure** (no `package:logging`, no Sentry, l10n-free) — all telemetry stays app-side.

---

## 2. Architecture

### 2.1 Platforms — iOS + Android only
Oubliette is wired only where it is genuinely hardware-backed (§1.2), and even there only after the §2.5 probe succeeds. macOS/Linux/Windows/Web collapse to FSS-only — which also keeps the Linux Secret Service `init()` probe out of the startup path and makes `capabilities().hardwareBacked` honest.

### 2.2 Profile — `evenLocked`, soft hardware requirement (locked)
```dart
Oubliette(
  android: AndroidSecretAccess.evenLocked(strongBox: false, requireHardwareBacking: false),
  darwin:  DarwinSecretAccess.evenLocked(secureEnclave: false),
)
```
`evenLocked` matches FSS's `AfterFirstUnlockThisDeviceOnly` (background ops keep working when locked) and avoids `KeyInvalidatedException` (§1.2). `requireHardwareBacking:false` (decision #4): on minSdk 30 every *real* device is TEE-backed regardless; the flag only governs whether generation *refuses* on a TEE-less device (emulators). Keeping it `false` avoids onboarding regressions with no security loss on real hardware. A device that still can't do oubliette is handled by the probe (→ FSS-only) and counted by the census — never warned.

### 2.3 Storage model — dual-read, new-writes-to-hardware, **no migrate-on-read**
The wired store is a thin **`DualReadStore`** decorator:
- **read** (`useAndForget`): hardware first; on **not-found only**, fall back to FSS (an un-migrated seed). A hardware read *failure* (`KeyInvalidated`/`Decryption`/lock) is **deliberately NOT** masked by the FSS copy — it surfaces as a typed failure so the app can telemeter hardware-degradation rates. Silently serving the retained FSS copy on every hardware fault would inflate the §2.5 compatibility census and risk removing FSS (decision #3) on falsely-clean data. A migrated seed whose hardware key dies is still recoverable from FSS, but via an explicit app-side policy on `KeyInvalidatedFailure`, not a silent read-path fallback. No write happens during a read.
- **write** (`store`): hardware only — every *new* seed is hardware-backed from creation.
- **trash/purge**: both backends. **keys/exists**: union / either.

Because reads never write, there is **no per-key lock, no purge gate, no resurrection race** — the entire concurrency apparatus the lazy design needed is gone.

### 2.4 Batch migration — explicit, index-driven, observable
Moving *existing* FSS seeds into hardware is a separate, one-time pass (`SecretMigrator`, exposed as `Secrets.migrateToHardware()`):
- **Index-driven**: iterate `SecretIndexPort.all()` (the source of truth for "what should exist"), so a deleted/index-removed seed is never resurrected.
- **Quiesced**: the app runs it once at startup, before the wallet UI is interactive — no concurrent secret op, so no locking needed.
- **Copy, don't move**: store each seed into oubliette and verify; **do not** trash the FSS copy. FSS stays a safety net until removed wholesale (Phase 4). One seed in memory at a time, zeroed after.
- **Idempotent**: already-migrated seeds are skipped, so a re-run only retries previous failures.
- **Per-device telemetry**: returns a `MigrationReport` (counts + per-seed failure *types*) that the app `log.shout`s. Failures are collected, never thrown — one bad seed never aborts the rest.

This is the controlled, observable migration decision #3 asks for: Sentry shows, per device, how many seeds migrated and *why* any failed.

### 2.5 Capability probe — a correctness gate, not just telemetry
`DualReadStore.store` writes only to hardware (no write-fallback — new seeds must not silently land in FSS). So on a device where oubliette is fundamentally unusable, a new import would **throw**. The fix is the same probe the census needs: only wire `DualReadStore(oubliette, fss)` on a device that proves a full oubliette round-trip; otherwise FSS-only. The probe (`store→useAndForget→trash` on a reserved key `__probe__`, distinct from `seed_*`) resolves to:

| Outcome | Cause | Wired this session | Persist flag? |
|---|---|---|---|
| **oubliette** | round-trip ok | `DualReadStore(oubliette, fss)` | yes → `oubliette` |
| **fssIncompatible** | non-recoverable `OublietteException` / `MissingPluginException` / structural | FSS-only | yes → `fss10` |
| **fssDeferred** | recoverable `OublietteException` (device locked) — capability unknown | FSS-only (this session) | **no** — re-probe next launch |

Branching on `OublietteException.recoverable` keeps the census honest: a device merely *locked at startup* is never miscounted as incompatible. The adapter reconstructs this recoverable/structural line via its (exhaustive) `_translate` switch rather than reading `e.recoverable` directly (the internal type also drives the user-facing failure); **`recoverable_translation_test.dart` pins that switch against `e.recoverable` for every sealed subtype**, so a future subtype mis-mapped to a structural internal type — which would permanently strand a transiently-locked device on FSS — fails CI. Once `oubliette` is committed, later launches trust the flag and skip the probe (no per-launch round-trip), exactly as `StorageLocator` trusts a committed `fss10`/`fss9`.

### 2.6 Two telemetry events (both via `log.shout`, `category: storage`)
1. **Capability census** — `secrets_backend=oubliette|fss10`, emitted once on flag transition (with the probe error on failure → *why* a device is FSS-only).
2. **Migration outcome** — `oubliette_migration migrated=N skipped=M failed=K`, emitted only when a pass actually does work (migrated>0 or failures present), with failure types attached.

Together these answer "how many devices are oubliette-capable vs FSS-only, and did their seeds migrate?" — on the same machinery as install-vs-upgrade.

---

## 3. API compatibility & exception translation (verified)

| `SecretStorePort` | Oubliette | Resolution |
|---|---|---|
| `init` | `init` | delegate + translate |
| `store` (throws if exists) | `store` (throws `StateError`) | `StateError` → `SecretAlreadyExistsException` |
| `useAndForget<R>` (throws if absent) | returns `R?` (null if absent) | null → `SecretNotFoundException` |
| `exists`/`trash`/`purge` | same | delegate (purge: no re-init — `store` self-heals the key) |
| `keys()` | **add in Phase 0** | reuse purge's prefix scan, strip `prefix+separator` |
| `capabilities()` | n/a | adapter returns `const StoreCapabilities(hardwareBacked:true, thisDeviceOnly:true, syncable:false)` — true on the only platforms it is wired |

**Exception translation** — exhaustive over the sealed `OublietteException`:

| `OublietteException` | `recoverable` | → BULL internal | → `SecretsFailure` |
|---|---|---|---|
| `AuthenticationFailedException` / `KeyringLockedException` / `BackendUnavailableException` | ✅ | `KeychainLockedException()` | `KeychainLockedFailure` |
| `KeyInvalidatedException` / `KeyNotFoundException` | ❌ | `HardwareKeyInvalidatedException(key)` *(new)* | `KeyInvalidatedFailure` *(new)* |
| `DecryptionFailedException` / `PayloadTamperException` / `PayloadCorruptException` | ❌ | `MalformedSecretException(typeName)` | `InvalidMnemonicFailure` |
| `StateError` (duplicate) | — | `SecretAlreadyExistsException` | `DuplicateSecretFailure` |

Verified constructor shapes: `MalformedSecretException(this.message)` (message **required** → pass `e.runtimeType.toString()`, never `cause`); `AndroidSecretAccess.evenLocked({required strongBox, required requireHardwareBacking})`; `DarwinSecretAccess.evenLocked({required secureEnclave})`. `KeyInvalidatedException`/`KeyNotFoundException` are a *permanent hardware-key-loss* mode FSS never had → dedicated `KeyInvalidatedFailure` ("re-enter your seed"), not `InvalidMnemonicFailure`/`SecretNotFoundFailure`.

---

## 4. Phases

### Phase 0 — Make oubliette ready (`dart-oubliette`) — ✅ DONE
**Committed** as `25a4887 feat(oubliette): add keys() to enumerate a profile's stored keys` on branch `refactor/security-hardening` (pushed; CI pending). +418 lines, additive.

`Future<List<String>> keys()` added — the non-destructive twin of `purge`'s prefix scan; returns logical keys (prefix + U+001D stripped), never raw slots, never any value (no `kSecReturnData` / `SECRET_SEARCH_LOAD_SECRETS`). Abstract in `oubliette.dart`; Android pure-Dart `SharedPreferences` scan (no native); Darwin `secItemListByPrefix` in `KeychainQueries.swift`/`KeychainPlugin.swift` + `Keychain.listByPrefix` facade; Linux `handle_list_by_prefix` in `secret_service_plugin.cc` + `SecretService.listByPrefix` facade. The two in-memory `Oubliette` test fakes gained `keys()`.

**Verified:** `make analyze` clean · **203 unit tests pass** (incl. new `keys()` groups on all 3 platforms: empty→`[]`, logical keys, shrinks after trash, `[]` after purge, sibling-prefix isolation, typed-exception-when-locked) · `make format` clean. The Linux C++ **compiled clean** (scaffolded `flutter build linux`: zero errors against the new code). Swift **not yet compiled** (no Xcode/macOS in CI) — verify on a real iOS/macOS build before release.

> ✅ **Pre-existing Linux blocker — NOW FIXED upstream (dart-oubliette `e7b79c1`).** The `flutter build linux` failure came from commit `72d3fd0`'s NUL-check calling `fl_value_get_string_size` — a symbol absent from the embedder header of both pinned 3.44.1 and 3.44.2 (only `fl_value_get_string` exists). `e7b79c1` dropped the impossible native length-compare (the guard now lives in the Dart `_rejectNul` + the native separator-terminated-prefix check), and the plugin compiles clean (verified via `g++ -fsyntax-only` against the 3.44.2 embedder headers). **Irrelevant to this BULL integration regardless** (oubliette is wired iOS+Android only, §2.1).

### Phase 1 — Package adapters + FSS hardening (`packages/secrets`) — ✅ DONE
**Done as planned, against `FakeOubliette` (no device).** All four oubliette siblings wired as **path deps** to `../../../dart-oubliette/*` (not git-pinned — local workspace), with root `dependency_overrides` for `keychain`/`keystore`/`secret_service` + `pointycastle: ^4.0.0` (the agreed "override for now"; see §5/Phase 5 for the constraint-bump follow-up). `OublietteSecretStoreAdapter`, `DualReadStore`, `SecretMigrator`+`MigrationReport`, `HardwareKeyInvalidatedException`+`KeyInvalidatedFailure`+the `secret_guard` catch, the §5.5 FSS buffer-zeroing, and the `Secrets.init` mode/outcome + `probeBackend()` + `migrateToHardware()` + `_buildOubliette` are all in. New tests: `fake_oubliette.dart`, `oubliette_secret_store_adapter_test.dart`, `dual_read_store_test.dart` (incl. migration), `secrets_init_outcome_test.dart`, + the FSS-hardening assertion. **`flutter analyze` clean; 211 tests green (was 175).** Deferred (post-Phase-1, tracked in §5/Phase 5): bump `pointycastle` constraints in the 4 SatoshiPortal-controlled repos + handle `hive`; full app compile + Ledger signing + hive legacy-migration on pc4; swap the path deps for a published/tagged oubliette pin.

**Second-round audit fixes (applied):** (1) the capability probe's trailing cleanup-`trash` is now best-effort and can no longer downgrade a capable device to `fssDeferred` (a successful round-trip resolves the outcome *before* cleanup); (2) `recoverable_translation_test.dart` pins the `_translate` recoverable/structural mapping (§2.5); (3) `migrateToHardware()` has an in-flight guard so an accidental concurrent second pass can't pollute the `MigrationReport` census with a write-once `StateError`; (4) the oubliette adapter's read/exists/trash/keys paths now also translate a raw `PlatformException` (symmetry with store/init); (5) FSS adapter constructed only on the real path, keeping the injected-store test seam hermetic; (6) the deliberate not-found-only read fallback (§2.3) and the dual-period `capabilities()` semantics are now documented in code. **Tracked, NOT fixed in Phase 1 (out of scope / pre-existing):** fresh-import `store→index.upsert` is non-atomic — an index-write failure after a successful store orphans the secret (pre-existing in `SecretLifecycleAdapter`, equally true for FSS; needs startup reconciliation via `keys()` vs index, an app-side concern); `DualReadStore.capabilities().hardwareBacked` is a per-store baseline that over-claims while un-migrated seeds remain in FSS (currently unconsumed — must not add a "require hardwareBacked" gate before Phase 4).

**Start by wiring the dependency** (required for the adapter + `FakeOubliette` to compile against `package:oubliette`): add all four — `oubliette`, `keychain`, `keystore`, `secret_service` — as **git deps pinned to `25a4887`** (they're unpublished and untagged; oubliette's hosted `^1.0.0` constraints on its siblings won't resolve, so all four must be git-pinned to the same ref). This first `pub get` **triggers the `pointycastle 3.9.1 → 4.x` bump** (§5/Phase 5) — run the workspace tests + an iOS/Android build *now*, not later, so a sibling pin conflict surfaces before any adapter code is written.

No device needed for the rest (develop against `FakeOubliette`). Create:
- `data/datasources/hardware_key_invalidated_exception.dart` (§5 types) + `KeyInvalidatedFailure` in `secrets_failure.dart` + the catch in `secret_guard.dart`.
- `OublietteSecretStoreAdapter` (§5.1), `DualReadStore` (§5.2), `SecretMigrator`+`MigrationReport` (§5.3).
- **§5.5 FSS hardening** — zero the read buffer (the migration reads through FSS; this is also a general improvement).
- `Secrets.init` mode/outcome + `probeBackend()` (standalone, testable via the `oubliette:` seam) + `migrateToHardware()` + `_buildOubliette` (§5.4); add the `store` field to `_Wiring`; export the new enums/types from the barrel.
- Tests (§6). All 175 existing tests stay green (+`await` on the two facade `Secrets.init` calls).

### Phase 2 — Probe + census, standalone (ships first, decision #2)
A **measure-only** build, shippable **before** the core/seed teardown and with **zero change to the seed path**. `StorageLocator` calls `Secrets.probeBackend()` (NOT `init` — Phase 2 does not adopt the package as the seed layer), reads the returned `SecretsInitResult`, persists the `SeedStorageLibrary` flag, and `log.shout`s `secrets_backend=…` (§2.6). Real seeds keep flowing through the existing `core/seed` + FSS path; the probe only touches its own `__probe__` sentinel in oubliette's namespace. **Goal: real Sentry compatibility numbers (and failure reasons) before committing to oubliette.**

### Teardown — adopt `secrets` as the seed layer (the `SECRETS_FACADE_PLAN`)
**The heavy prerequisite for Phase 3, sitting between Phase 2 and Phase 3.** Replace `core/seed`'s storage + crypto (`SeedDatasource`/`SeedRepository` + the seed read/sign/derive paths) with `Secrets.*`; `Secrets.init` becomes the seed path. **Survives app-side** (the package can't own it): the backend flag + census (`SeedStorageLibrary`/`StorageLocator`), the Drift `SecretIndexPort` impl, and the legacy one-time migrations (v4/v5/OldHive). **No data move** — the package's FSS adapter reads the existing `seed_<fp>` keys in place (`legacy_format_test` proves it parses the current app format). This is its own large effort (the `SECRETS_FACADE_PLAN`), tracked separately; the oubliette work here is gated behind it.

### Phase 3 — Enable hardware storage + batch migration (gated on Phase 2 data + teardown)
With the package now the seed layer: for `oubliette`-flagged devices `Secrets.init(mode: oublietteFirst|autoDetect)` wires `DualReadStore` (new seeds → oubliette), then `Secrets.migrateToHardware()` runs once at startup and the app `log.shout`s the `MigrationReport` (§2.4/§2.6). FSS retained as fallback + safety net. Device integration tests on iOS + Android(30+).

### Phase 4 — Remove FSS (data-driven, decision #3)
When the census shows the incompatible cohort is negligible **and** migration reports show near-zero failures across N releases: trash the FSS seed copies, replace `DualReadStore` with `OublietteSecretStoreAdapter` directly, delete the FSS adapter chain + dependency, and (optionally) tighten Android to `requireHardwareBacking:true`.

### Phase 5 — Dependencies (throughout)
Add `oubliette` + the three siblings (path deps for dev; git deps pinned to one `ref` for CI; pub.dev for prod). **`pointycastle` bump (verify before merge):** oubliette needs `^4.0.0`; BULL resolves `3.9.1` transitively (bdk_dart/bull_sdk/recoverbull). `flutter pub get` bumps the lock repo-wide → run the workspace tests (esp. seed derivation, signing, `test/crypto/kat_test.dart`) + build iOS/Android. A sibling hard-pinning `<4` is a RED block to resolve upstream.

---

## 5. Code

### 5.1 `OublietteSecretStoreAdapter`
```dart
import 'dart:typed_data';
import 'package:flutter/services.dart' show PlatformException;
import 'package:oubliette/oubliette.dart';
import 'package:secrets/src/data/datasources/hardware_key_invalidated_exception.dart';
import 'package:secrets/src/data/datasources/keychain_locked_exception.dart';
import 'package:secrets/src/data/datasources/malformed_secret_exception.dart';
import 'package:secrets/src/data/datasources/secret_not_found_exception.dart';
import 'package:secrets/src/domain/ports/secret_store_port.dart';

/// [SecretStorePort] backed by oubliette. Wired only on iOS/Android (where it is
/// genuinely hardware-backed). Translates the sealed [OublietteException] family
/// into BULL's internal exceptions and maps null-on-absent to [SecretNotFoundException].
class OublietteSecretStoreAdapter implements SecretStorePort {
  const OublietteSecretStoreAdapter(this._o);
  final Oubliette _o;

  @override
  Future<void> init() async {
    try { await _o.init(); }
    on OublietteException catch (e) { throw _translate(e, null); }
    on PlatformException catch (e) { throw _classifyRaw(e); }
  }

  @override
  StoreCapabilities capabilities() => const StoreCapabilities(
        hardwareBacked: true, thisDeviceOnly: true, syncable: false);

  @override
  Future<void> store(String key, Uint8List value) async {
    try { await _o.store(key, value); }
    on StateError { throw SecretAlreadyExistsException(key); }
    on OublietteException catch (e) { throw _translate(e, key); }
    on PlatformException catch (e) { throw _classifyRaw(e); }
  }

  /// [R] must be non-void (a void action returns null even on a hit). Every BULL
  /// caller returns a concrete non-nullable type, so this holds.
  @override
  Future<R> useAndForget<R>(String key, Future<R> Function(Uint8List) use) async {
    try {
      final r = await _o.useAndForget(key, use);
      if (r == null) throw SecretNotFoundException(key);
      return r;
    } on OublietteException catch (e) { throw _translate(e, key); }
  }

  @override
  Future<bool> exists(String key) async {
    try { return await _o.exists(key); }
    on OublietteException catch (e) { throw _translate(e, key); }
  }

  @override
  Future<void> trash(String key) async {
    try { await _o.trash(key); }
    on OublietteException catch (e) { throw _translate(e, key); }
  }

  /// No re-init: oubliette re-mints the key lazily on the next `store` (Android),
  /// and iOS has no app key. Reads after purge correctly return not-found.
  @override
  Future<void> purge() async {
    try { await _o.purge(); }
    on OublietteException catch (e) { throw _translate(e, null); }
  }

  @override
  Future<List<String>> keys() async {
    try { return await _o.keys(); }
    on OublietteException catch (e) { throw _translate(e, null); }
  }

  /// Exhaustive over the sealed [OublietteException]; carries only the runtime
  /// type name (never `cause`/`keyAlias`, which can hold OEM/biometric text).
  Exception _translate(OublietteException e, String? key) => switch (e) {
        AuthenticationFailedException() => const KeychainLockedException(),
        KeyringLockedException() => const KeychainLockedException(),
        BackendUnavailableException() => const KeychainLockedException(),
        KeyInvalidatedException() => HardwareKeyInvalidatedException(key: key),
        KeyNotFoundException() => HardwareKeyInvalidatedException(key: key),
        DecryptionFailedException() => MalformedSecretException(e.runtimeType.toString()),
        PayloadTamperException() => MalformedSecretException(e.runtimeType.toString()),
        PayloadCorruptException() => MalformedSecretException(e.runtimeType.toString()),
      };

  /// Oubliette leaves a few codes raw (`strongbox_unavailable`/`hardware_unavailable`
  /// — only with `strongBox`/`requireHardwareBacking` set, i.e. not phase 1 —
  /// `bad_args`, unknown OEM codes). Classify a locked signal; rethrow the rest
  /// (an unknown → `SecretsUnexpectedFailure`, never a silent not-found).
  Exception _classifyRaw(PlatformException e) =>
      isKeychainLockedError(e) ? const KeychainLockedException() : e;
}
```

### 5.2 `DualReadStore` (replaces the lazy `FallbackSecretStoreAdapter`)
```dart
import 'dart:typed_data';
import 'package:secrets/src/data/datasources/secret_not_found_exception.dart';
import 'package:secrets/src/data/migration/secret_migrator.dart';
import 'package:secrets/src/domain/ports/secret_index_port.dart';
import 'package:secrets/src/domain/ports/secret_store_port.dart';

/// Reads hardware (oubliette) first, falls back to FSS; NEW writes go to
/// hardware only. NO migrate-on-read — bulk migration is an explicit quiesced
/// pass ([migratePending]), so this decorator never writes during a read and
/// needs no per-key lock or purge gate. FSS is a read fallback + safety net
/// until removed wholesale (Phase 4).
class DualReadStore implements SecretStorePort {
  DualReadStore({required SecretStorePort hardware, required SecretStorePort fallback})
      : _hw = hardware, _fss = fallback;
  final SecretStorePort _hw;
  final SecretStorePort _fss;

  @override
  Future<void> init() async { await _hw.init(); await _fss.init(); }

  @override
  StoreCapabilities capabilities() => _hw.capabilities();

  @override
  Future<void> store(String key, Uint8List value) => _hw.store(key, value);

  @override
  Future<R> useAndForget<R>(String key, Future<R> Function(Uint8List) use) async {
    // `used`: a SecretNotFoundException is a hardware MISS only if `use` never
    // ran. If `use` threw it after receiving bytes, the key WAS in hardware —
    // rethrow, don't fall back (and don't re-invoke `use`).
    var used = false;
    Future<R> once(Uint8List b) { used = true; return use(b); }
    try {
      return await _hw.useAndForget(key, once);
    } on SecretNotFoundException {
      if (used) rethrow;
    }
    return _fss.useAndForget(key, use); // un-migrated seed → read from FSS
  }

  @override
  Future<bool> exists(String key) async =>
      (await _hw.exists(key)) || (await _fss.exists(key));

  /// Remove from both. No migrate-on-read can resurrect a half-deleted seed, and
  /// the index-driven migrator never re-migrates an index-removed seed, so a
  /// partial failure is just a failed delete that converges on retry.
  @override
  Future<void> trash(String key) async { await _hw.trash(key); await _fss.trash(key); }

  @override
  Future<void> purge() async { await _hw.purge(); await _fss.purge(); }

  @override
  Future<List<String>> keys() async =>
      {...await _hw.keys(), ...await _fss.keys()}.toList(growable: false);

  /// Phase 3: one-time FSS→hardware migration.
  Future<MigrationReport> migratePending(SecretIndexPort index) =>
      SecretMigrator(hardware: _hw, fallback: _fss, index: index).run();
}
```

### 5.3 `SecretMigrator` + `MigrationReport`
```dart
import 'dart:typed_data';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/adapters/fss_secret_store_adapter.dart' show SecretStoreKeys;
import 'package:secrets/src/domain/ports/secret_index_port.dart';
import 'package:secrets/src/domain/ports/secret_store_port.dart';

/// Outcome of one FSS→hardware pass. Pure data — the app `log.shout`s it.
class MigrationReport {
  const MigrationReport({required this.migrated, required this.skipped, required this.failures});
  final int migrated;   // newly copied into hardware this pass
  final int skipped;    // already in hardware
  final List<({Fingerprint fingerprint, String errorType})> failures;
  bool get complete => failures.isEmpty;
  bool get didWork => migrated > 0 || failures.isNotEmpty; // gate the shout (no steady-state spam)
  int get total => migrated + skipped + failures.length;
}

/// Copies every indexed secret not yet in [_hw] from [_fss] into [_hw], one at a
/// time, verifying each. FSS copies are NOT trashed (safety net until Phase 4).
/// Index-driven (a deleted seed is never resurrected). Idempotent (already-migrated
/// skipped → a re-run retries only failures). Per-secret errors are collected,
/// never thrown, so one bad seed never aborts the rest.
class SecretMigrator {
  SecretMigrator({required SecretStorePort hardware, required SecretStorePort fallback, required SecretIndexPort index})
      : _hw = hardware, _fss = fallback, _index = index;
  final SecretStorePort _hw;
  final SecretStorePort _fss;
  final SecretIndexPort _index;

  Future<MigrationReport> run() async {
    var migrated = 0, skipped = 0;
    final failures = <({Fingerprint fingerprint, String errorType})>[];
    for (final info in await _index.all()) {
      final key = SecretStoreKeys.seedKey(info.fingerprint.hex);
      try {
        if (await _hw.exists(key)) { skipped++; continue; }
        await _fss.useAndForget(key, (bytes) async {
          final copy = Uint8List.fromList(bytes);          // FSS zeroes `bytes` (§5.5)
          try { await _hw.store(key, copy); }
          finally { copy.fillRange(0, copy.length, 0); }   // we zero our copy
        });
        if (await _hw.exists(key)) { migrated++; }
        else { failures.add((fingerprint: info.fingerprint, errorType: 'verify_failed')); }
      } on Exception catch (e) {
        // Includes a dangling index entry (seed in neither store) →
        // 'SecretNotFoundException'; surfaced, never silently dropped.
        failures.add((fingerprint: info.fingerprint, errorType: e.runtimeType.toString()));
      }
    }
    return MigrationReport(migrated: migrated, skipped: skipped, failures: failures);
  }
}
```

### 5.4 `Secrets.init()` (mode + probe + outcome) and `migrateToHardware()`
```dart
enum SecretsStorageMode { autoDetect, oublietteFirst, fssOnly }            // exported
enum SecretsBackendOutcome { oubliette, fssIncompatible, fssDeferred }     // exported
typedef SecretsInitResult = ({SecretsBackendOutcome outcome, Object? probeError});

static _Wiring? _instance;                 // _Wiring exposes `store` and `index`
static Future<SecretsInitResult>? _initInFlight;

static Future<SecretsInitResult> init({
  required SecretIndexPort index,
  SecretsStorageMode mode = SecretsStorageMode.autoDetect,
  SecretStorePort? store,                  // test seam; bypasses mode/probe
}) => _initInFlight ??= _doInit(index: index, mode: mode, store: store);

static Future<SecretsInitResult> _doInit({
  required SecretIndexPort index,
  required SecretsStorageMode mode,
  SecretStorePort? store,
}) async {
  try {
    final (SecretStorePort s, SecretsInitResult result) = await _resolveStore(mode, store);
    await s.init();
    _instance = _Wiring(store: s, index: index);
    return result;
  } catch (_) { _initInFlight = null; rethrow; }   // allow retry after a failed init
}

static Future<(SecretStorePort, SecretsInitResult)> _resolveStore(
    SecretsStorageMode mode, SecretStorePort? injected) async {
  final fss = FssSecretStoreAdapter(FlutterSecureStorageAdapter.standard());
  if (injected != null) return (injected, (outcome: SecretsBackendOutcome.oubliette, probeError: null));
  final o = _buildOubliette();                              // null where oubliette isn't wired (§2.1)
  if (o == null || mode == SecretsStorageMode.fssOnly) {
    return (fss, (outcome: SecretsBackendOutcome.fssIncompatible, probeError: null));
  }
  final dual = DualReadStore(hardware: o, fallback: fss);
  if (mode == SecretsStorageMode.oublietteFirst) {         // flag says capable — trust it
    return (dual, (outcome: SecretsBackendOutcome.oubliette, probeError: null));
  }
  final probe = await _probe(o);                            // autoDetect
  return switch (probe.outcome) {
    SecretsBackendOutcome.oubliette => (dual, probe),
    _ => (fss, probe),                                       // incompatible | deferred → FSS-only
  };
}

/// Builds the oubliette-backed adapter for this device, or null where oubliette
/// is not wired (macOS/Linux/Windows/Web — §2.1). [injected] is the test seam
/// (a `FakeOubliette`) that also bypasses the platform gate.
static OublietteSecretStoreAdapter? _buildOubliette({Oubliette? injected}) {
  final supported = defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;
  if (injected == null && !supported) return null;
  return OublietteSecretStoreAdapter(injected ?? Oubliette(
    android: AndroidSecretAccess.evenLocked(strongBox: false, requireHardwareBacking: false),
    darwin:  DarwinSecretAccess.evenLocked(secureEnclave: false),
  ));
}

/// **PHASE 2 entry** — probe device capability WITHOUT wiring the package as the
/// seed layer (so the census can ship before the core/seed teardown). The probe
/// round-trip, the backend choice, and the adapters all stay SEALED in the
/// package; this returns only non-secret data (outcome enum + probe error) for
/// the app to persist the `SeedStorageLibrary` flag and `log.shout`. The
/// `oubliette:` param is a test seam (`FakeOubliette`) — the only way to drive
/// the probe outcomes from a unit test, since `_buildOubliette` otherwise
/// constructs the real platform Oubliette.
static Future<SecretsInitResult> probeBackend({Oubliette? oubliette}) async {
  final o = _buildOubliette(injected: oubliette);
  if (o == null) return (outcome: SecretsBackendOutcome.fssIncompatible, probeError: null);
  return _probe(o);
}

static const _probeKey = '__probe__';                       // not seed_*, ignored by reconciliation
static Future<SecretsInitResult> _probe(OublietteSecretStoreAdapter o) async {
  final bytes = Uint8List.fromList(const [0x0b, 0xb1]);
  try {
    await o.init();
    await o.trash(_probeKey);                                // clear any stale sentinel
    await o.store(_probeKey, bytes);
    final ok = await o.useAndForget(_probeKey,
        (b) async => b.length == 2 && b[0] == bytes[0] && b[1] == bytes[1]);
    await o.trash(_probeKey);
    return (outcome: ok ? SecretsBackendOutcome.oubliette : SecretsBackendOutcome.fssIncompatible, probeError: null);
  } on KeychainLockedException catch (e) {                   // recoverable → unknown, retry later
    return (outcome: SecretsBackendOutcome.fssDeferred, probeError: e);
  } on Exception catch (e) {                                 // structural → incompatible
    return (outcome: SecretsBackendOutcome.fssIncompatible, probeError: e);
  }
}

/// Phase 3: runs the one-time FSS→hardware migration if a hardware backend is
/// active; returns null on an FSS-only device. The app `log.shout`s the report.
static Future<MigrationReport?> migrateToHardware() async {
  final store = _w.store;
  return store is DualReadStore ? store.migratePending(_w.index) : null;
}

@visibleForTesting
static void reset() { _instance = null; _initInFlight = null; }
```
A one-shot guard keeps the now-`async` `init` idempotent (concurrent/duplicate calls share one future; a failed init clears it). Callers `await Secrets.init(...)` before the first `Secrets.*` op (unchanged contract).

### 5.5 Harden `FssSecretStoreAdapter.useAndForget` to zero its buffer (existing code)
Today it is `return use(_decode(value));` — no `await`, no zeroing, so every FSS read (and the migration) leaves plaintext resident. The `await` is mandatory (else the `finally` zeroes before the async callback runs):
```dart
if (value != null) {
  final bytes = _decode(value);
  try { return await use(bytes); }
  finally { bytes.fillRange(0, bytes.length, 0); }
}
```
The underlying base64 `String` from the channel is immutable and unzeroable (the string-vs-bytes limit oubliette exists to fix) — zeroing the decoded `Uint8List` is the best FSS can do. Relies on `use`/`Mnemonic.fromStorageBytes` not retaining a view past return — the invariant oubliette already depends on. The 175 tests pass with this added.

### 5.6 App-side wiring (`lib/`) — adoption-time, but designed now
**Sealing boundary (important):** the probe round-trip, the backend choice, and the storage adapters all stay **sealed inside the package** (`SecretStorePort`/`OublietteSecretStoreAdapter`/`DualReadStore`/`FssSecretStoreAdapter` are `src/`, unexported — the app *cannot* construct them). The app calls `Secrets.probeBackend()` / `Secrets.init(mode:)` and receives only **non-secret data** (`SecretsBackendOutcome` + `probeError`; the probe uses a fixed sentinel, so no secret ever crosses). What stays app-side is *only* the non-secret plumbing it already owns today for fss10/fss9: persisting the `SeedStorageLibrary` flag and emitting `log.shout` (the package is pure/logging-free by design). Adopting the package in fact *moves* the storage construction + probe out of today's app-side `StorageLocator` into the package — tightening the seal, not breaking it.

**Extend `SeedStorageLibrary`** (`seed_store_type.dart`):
```dart
enum SeedStorageLibrary { oubliette, fss10, fss9 }
// isLegacyStorage stays fss9-only (decision #4: no warning for fss10/oubliette).
// Optional soft signal: bool get isHardwareBacked => storageLibrary == SeedStorageLibrary.oubliette;
```

**`StorageLocator`** — emit the census on transition (commit-after-shout). The `result` comes from `probeBackend()` in Phase 2 and from `init(mode:)` in Phase 3; the census block below is shared.
```dart
// DECISION (doubt #4): when do we (re)probe? null & fssDeferred MUST re-probe
// (no definite answer yet). For a definite `fss10`, re-probing every launch
// catches a device made capable by an OS update, at a per-launch round-trip
// cost. Shown here as "re-probe fss10"; flip `reprobe` to exclude fss10 to
// trust the flag and re-probe only on an app-version bump.
final reprobe = existingLibrary == null || existingLibrary == SeedStorageLibrary.fss10;

// ── Phase 2 (standalone census — package is NOT the seed layer) ──
final result = reprobe ? await Secrets.probeBackend() : null;
// ── Phase 3 replaces the line above (package IS the seed layer): ──
//   final mode = switch (existingLibrary) {
//     null, SeedStorageLibrary.fss10 => SecretsStorageMode.autoDetect,
//     SeedStorageLibrary.oubliette   => SecretsStorageMode.oublietteFirst, // trust flag
//     SeedStorageLibrary.fss9        => SecretsStorageMode.fssOnly,
//   };
//   final result = await Secrets.init(index: driftIndex, mode: mode);

// ── Census (shared) — persist the flag + log.shout on transition ──
if (result != null) {
  final resolved = switch (result.outcome) {
    SecretsBackendOutcome.oubliette       => SeedStorageLibrary.oubliette,
    SecretsBackendOutcome.fssIncompatible => SeedStorageLibrary.fss10,
    SecretsBackendOutcome.fssDeferred     => null, // unknown — don't persist, re-probe next launch
  };
  if (resolved != null && resolved != existingLibrary) {
    await log.shout(                                 // emit BEFORE commit (crash-retry)
      message: 'secrets_backend=${resolved.name}',
      error: result.probeError,                      // captures WHY a device is FSS-only
      category: ReportCategory.storage,
    );
    await seedStoreTypeDatasource.write(
      SeedStoreTypeModel.fromEntity(SeedStoreType(storageLibrary: resolved)));
  }
}

// ── Phase 3 ONLY — migrate existing FSS seeds into oubliette, then report ──
final report = await Secrets.migrateToHardware();     // null on FSS-only devices
if (report != null && report.didWork) {
  await log.shout(
    message: 'oubliette_migration migrated=${report.migrated} skipped=${report.skipped} failed=${report.failures.length}',
    error: report.failures.isEmpty ? null
        : Exception(report.failures.map((f) => f.errorType).toSet().join(',')),
    category: ReportCategory.storage,
  );
}
```
- **Phase 2** runs only the `probeBackend()` + census block — no `init`, no `migrateToHardware`; real seeds keep flowing through `core/seed` + FSS. **Phase 3** (after the teardown) swaps in `init(mode:)` and adds the migration block.
- **No per-launch spam:** census fires only on flag change; migration fires only when `didWork`. A fully-migrated device is silent; a device with persistent failures shouts every launch (so you see it).
- **Add `ReportCategory.storage`** (`report.dart`) so the backend census filters apart from schema/version migrations. `_applyTags` already serializes `category=<name>`.

---

## 6. Test plan

**`FakeOubliette`** (`test/data/fake_oubliette.dart`): in-memory `Oubliette` via `super.internal()`, `Map<String,Uint8List>`, error-injection flags (`locked`→`AuthenticationFailedException`, `backendUnavailable`→`BackendUnavailableException`, `keyInvalidated`→`KeyInvalidatedException`), `keys()`→map keys.

**`OublietteSecretStoreAdapter`**: round-trip; duplicate→`SecretAlreadyExistsException`; absent→`SecretNotFoundException`; purge-then-store works without re-init; `keys()` logical (empty after purge); every §3 mapping; `init` translates (+`_classifyRaw` for a raw locked `PlatformException`); `capabilities` hardware/this-device/non-syncable.

**`DualReadStore`**: read hardware-hit → FSS untouched; hardware-miss → FSS hit; `store`→hardware only; `use` that throws `SecretNotFoundException` after running → propagates (the `used` guard, `use` invoked once); `exists`/`keys` union; `trash` both; partial-trash converges on retry (no resurrection); `init` inits both.

**`SecretMigrator`**: migrates only seeds absent from hardware (skips present); copies + verifies; **FSS copy retained** after migration; per-seed failure collected with its type, others still migrate; dangling index entry (in neither store) → a `failures` entry, never thrown; idempotent re-run = all skipped (`didWork == false`).

**Probe outcome** (via `Secrets.probeBackend(oubliette: FakeOubliette()…)` — the `oubliette:` seam is what makes these drivable): round-trip ok → `oubliette`; non-recoverable throw (`keyInvalidated`/corrupt/`MissingPlugin`) → `fssIncompatible` + `probeError`; recoverable throw (`locked`) → `fssDeferred`; sentinel `__probe__` absent after a successful probe (assert via the fake). **`init` outcome** (via injected `store:`): `oublietteFirst` → `DualReadStore` wired, no probe; `fssOnly`/non-iOS-Android → FSS; concurrent `init`×2 → one wiring (idempotency guard).

**FSS hardening (§5.5)**: decoded buffer zeroed after `useAndForget`; 175 existing tests still green.

**App census/migration (pure logic, fake datasource + fake logger)**: flag `null`+`oubliette` → writes `oubliette` and one `secrets_backend=oubliette` shout, shout **before** the flag write; `null`+`fssIncompatible` → `fss10` + shout carrying `probeError`; `null`+`fssDeferred` → no write, no shout; flag already `oubliette` → no shout, mode `oublietteFirst` (no re-probe); migration `didWork` → one `oubliette_migration` shout with counts; steady-state (all skipped) → no migration shout.

**Integration (device, Phase 3)**: iOS + Android(30+) full lifecycle; pre-seed FSS → run migration → both stores hold the seed, reads hit oubliette; Android `keys()` excludes sibling-profile entries.

---

## 7. Risk register

| Risk | Status / mitigation |
|---|---|
| New import **throws** on an oubliette-incapable device (`store` has no write-fallback) | **Fixed** by the §2.5 probe — such a device resolves to FSS-only, never wired to `DualReadStore`. |
| Capability probe miscounts a *locked* device as incompatible | **Fixed** — branch on `recoverable` → `fssDeferred` (use FSS this session, persist nothing, re-probe). |
| Batch migration partial failure | Failures collected + `log.shout`'d + retried next launch (idempotent). FSS copy retained → **no data loss**; reads still find the un-migrated seed via dual-read. |
| Bulk plaintext exposure during migration | One seed at a time; each FSS buffer zeroed (§5.5) and the migration copy zeroed; typically 1–3 seeds. |
| Deleted seed resurrected by migration | **Cannot happen** — migration is index-driven; a deleted seed is index-removed, so it is never re-migrated. (Lazy-migration's resurrection races are gone with the model.) |
| FSS read buffer never zeroed | **Fixed** by §5.5. |
| `use` closure throwing `SecretNotFoundException` → wrong fallback / double-invoke | **Fixed** by the `used` guard (§5.2). |
| Async `Secrets.init()` double-init race | **Fixed** by the one-shot `_initInFlight` guard. |
| Raw `PlatformException` escapes translation | **Defended** — `_classifyRaw` on `store`/`init`. |
| `pointycastle 3.9.1 → 4.x` bump | **Verify in Phase 5** (build + KAT/signing/derivation tests); RED if a sibling pins `<4`. |
| Hardware key lost (factory reset / new phone) → seed unrecoverable on-device | **Accepted (decision #5)** — same as FSS; recovery is the user's own backup. `evenLocked` is immune to `KeyInvalidatedException`; `allowBackup="false"` already set (must stay). |
| Unpublished oubliette siblings break resolution | Path/git deps at one ref; publish before shipping. |
| Unit tests build the real default store | Facade test already injects a store; keep that invariant. |
| minSdk 30 drops Android ≤10 | Accepted by maintainer (out of scope). |

---

## 8. File changelist

**✅ DONE — `dart-oubliette` (commit `25a4887`):** `keys()` in `oubliette.dart` + `android/darwin/linux_oubliette.dart`; `listByPrefix` in `keychain.dart` + the shared Swift source (`KeychainPlugin.swift`/`KeychainQueries.swift`); `listByPrefix` in `secret_service.dart` + `secret_service_plugin.cc`; the three `*_oubliette_test.dart` (+`keys()` tests) and the two in-memory fakes. *Outstanding for that repo (not BULL): publish/tag for a stable pin, fix the pre-existing `fl_value_get_string_size` Linux blocker, compile the Swift on a real build.*

**Create — `packages/secrets`:** `data/datasources/hardware_key_invalidated_exception.dart`; `data/adapters/oubliette_secret_store_adapter.dart`; `data/adapters/dual_read_store.dart`; `data/migration/secret_migrator.dart` (+`MigrationReport`); `test/data/fake_oubliette.dart` + adapter/migrator/probe/census tests.
**Modify — `packages/secrets`:** `domain/secrets_failure.dart` (+`KeyInvalidatedFailure`); `data/adapters/secret_guard.dart` (+catch); `data/adapters/fss_secret_store_adapter.dart` (§5.5 zero); `secrets_api.dart` (`init` mode/outcome + `probeBackend` + `migrateToHardware` + `_buildOubliette` + `_Wiring.store`); `secrets.dart` barrel (export the enums + `MigrationReport` + `SecretsInitResult`); `pubspec.yaml` (4 deps → `pointycastle` bump); `test/facade/secrets_facade_test.dart` (+`await`).

**Modify — `BULL` app (adoption-time):** `lib/core/seed/domain/entity/seed_store_type.dart` (+`oubliette`); `lib/core/storage/storage_locator.dart` (mode mapping, census shout, Phase-3 migration shout); `lib/core/utils/report.dart` (`ReportCategory` +`storage`). No change to `SeedStoreTypeDatasource`/`SeedStoreTypeModel` (serialize by `.name`).
**Verify (no edit) — BULL root:** `flutter pub get` → `pointycastle 4.x`; run workspace tests + iOS/Android build before merge. `android:allowBackup="false"` stays set.
**Optional hardening:** `R extends Object` on `SecretStorePort.useAndForget` + impls (compile-time guard for the non-null-`R` assumption).

---

## 9. Execution order

```
Phase 0  dart-oubliette: add keys() (native)                     ── ✅ DONE (commit 25a4887; repo publish still pending)
Phase 1  package: adapters + DualReadStore + SecretMigrator       ── ✅ DONE (analyze clean; 211 tests green; pc4 via override)
         + FSS hardening + init/probeBackend/outcome + tests (175 green)
Phase 2  app: Secrets.probeBackend() + census, STANDALONE         ── ships first; core/seed STILL the seed path (decision #2)
            ↓ read Sentry: how many devices oubliette-capable, and why the rest aren't
Teardown adopt secrets as the seed layer (SECRETS_FACADE_PLAN)    ── heavy prerequisite; package reads existing FSS in place
Phase 3  app: Secrets.init wires DualReadStore + batch migrate    ── gated on Phase 2 data + teardown (decision #3)
            ↓ read Sentry: per-device migration success/failure
Phase 4  remove FSS (trash copies, drop dep, maybe requireHardwareBacking:true) ── when failures ≈ 0 across N releases
```

The census (Phase 2) and the migration reports (Phase 3) are exactly the data that tells you when Phase 4 is safe: failures visible → postpone FSS removal; clean → bring it forward.
