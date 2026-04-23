# FSS Channel Collision Diagnosis

**Affected release tag:** `6.8.2-fss-hybrid` (also `v6.8.1-fss-hybrid` — identical library refs)
**Library versions at that tag:**
- FSS10: `SatoshiPortal/flutter_secure_storage @ 47ad06f`
- FSS9: `SatoshiPortal/flutter_secure_storage_legacy @ c32db29`

**Fixed in:** FSS10 @ `6530bef`, FSS9 @ `01ed2ee` (shipped in 6.9.0+)

---

## 1. The Actual Bug

### Not the Android channel

`c32db29` already fixed the **Android** channel: it changed `FlutterSecureStoragePlugin.java` from
`plugins.it_nomads.com/flutter_secure_storage` to `plugins.it_nomads.com/flutter_secure_storage_legacy`.
The commit message confirms this: _"fix: use unique method channel name to prevent collision with fss10"_.

### The real collision: Dart platform interface import

`FSS9@c32db29 flutter_secure_storage/lib/flutter_secure_storage.dart`:
```dart
// WRONG — resolves to FSS10's platform interface at compile time
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
```

`FSS9@01ed2ee flutter_secure_storage/lib/flutter_secure_storage.dart`:
```dart
// CORRECT
import 'package:flutter_secure_storage_legacy_platform_interface/flutter_secure_storage_platform_interface.dart';
```

FSS9's `pubspec.yaml` (at both commits) correctly names its platform interface dependency
`flutter_secure_storage_legacy_platform_interface`. But at c32db29 the Dart import references
`flutter_secure_storage_platform_interface` — which the Dart resolver maps to FSS10's copy of that
package (brought in transitively through FSS10's own pubspec).

FSS10's platform interface uses channel `plugins.it_nomads.com/flutter_secure_storage`.
FSS9's Android handler is registered on `plugins.it_nomads.com/flutter_secure_storage_legacy`.

**Result:** ALL Dart method channel calls from both `fss10.FlutterSecureStorage(...)` and
`fss9.FlutterSecureStorage(...)` are routed to **FSS10's Android handler**. FSS9's Android handler
is never called.

---

## 2. Effect on `storage_locator.dart` in 6.8.2

`storage_locator.dart` implements an FSS10-first, FSS9-fallback pattern. When the locator creates
the FSS9 fallback instance:

```dart
fss9.FlutterSecureStorage(
  aOptions: fss9.AndroidOptions(encryptedSharedPreferences: true, resetOnError: false),
)
```

...and calls `storage.readAll()`, the Dart method channel routes to FSS10's Android handler, not
FSS9's. The options map `{"encryptedSharedPreferences": "true", "resetOnError": "false"}` is
parsed by FSS10's `FlutterSecureStorageConfig`, which understands all those keys.

FSS10 Android fully supports `encryptedSharedPreferences: true`. It executes its own ESP code path:
checks `ENCRYPTED_PREFERENCES_MIGRATED`, runs `checkAndMigrateToEncrypted()` if not yet migrated,
and reads from Tink EncryptedSharedPreferences if already migrated.

The FSS9 fallback in 6.8.2 is therefore not a fallback to a different storage system — it is FSS10
Android called again with different options.

---

## 3. Storage Topology (Shared by Both Libraries)

Both FSS10 and FSS9 read from and write to the same Android storage locations:

| Resource | Name |
|---|---|
| Data SharedPreferences | `FlutterSecureStorage` |
| Key blob SharedPreferences | `FlutterSecureKeyStorage` |
| Algorithm config (FSS10 only) | `FlutterSecureStorageConfiguration` |
| Keystore RSA key (PKCS1) | `{package}.FlutterSecureStoragePluginKey` |
| Keystore RSA key (OAEP) | `{package}.FlutterSecureStoragePluginKeyOAEP` |
| AES blob name (GCM) | `AESVGhpcyBpcyB0aGUga2V5IGZvciBhIHNlY3VyZSBzdG9yYWdlIEFFUyBLZXkK` |
| AES blob name (CBC) | `VGhpcyBpcyB0aGUga2V5IGZvciBhIHNlY3VyZSBzdG9yYWdlIEFFUyBLZXkK` |
| Data entry key prefix | `VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIHNlY3VyZSBzdG9yYWdlCg` |

Both libraries share all of these. There is no namespace separation at the storage level.

---

## 4. Pre-6.8.x Baseline State

Before the fss-hybrid PR (#2021), `storage_locator.dart` used only FSS10@f0d4b6cd:

```dart
FlutterSecureStorage(aOptions: AndroidOptions(resetOnError: false, migrateWithBackup: true))
```

FSS10@f0d4b6cd defaults: `AES_GCM_NoPadding` storage cipher + `RSA_ECB_PKCS1Padding` key cipher.
`migrateOnAlgorithmChange` defaults to `true`.

On first launch with f0d4b6cd, if no `FlutterSecureStorageConfiguration` existed, the factory
assumed saved = CBC (fallback default), current = GCM → migration triggered. For a fresh install
this trivially succeeds (no data). For a user with old FSS9 CBC data, GCM migration ran. Either
way, after one launch on f0d4b6cd:

- `FlutterSecureStorageConfiguration` has `AES_GCM_NoPadding` + `RSA_ECB_PKCS1Padding` markers
- Data is in GCM+PKCS1 format
- `_BACKUP` entries are removed by step 7 of `migrateNonBiometricWithBackup` after success

---

## 5. Failure Scenarios

### Scenario 1: Users who ran f0d4b6cd before updating to 6.8.2 (most users)

**Pre-state:** GCM+PKCS1 markers in `FlutterSecureStorageConfiguration`. Data in GCM format. No `_BACKUP` entries.

**6.8.2 first launch:**
1. `SeedStoreType` = null → tries FSS10@47ad06f
2. `StorageCipherFactory`: saved = GCM+PKCS1, current = GCM+PKCS1 → `requiresReEncryption()` = false
3. `readAll()` succeeds directly — no migration, no FSS9 fallback
4. FSS10 flag written

**Impact: None.** Channel collision has zero effect on these users.

---

### Scenario 2: Users with missing config markers / partial migration failure

**Pre-state:** No `FlutterSecureStorageConfiguration` (very old install, or came from ESP-only FSS9
without ever running f0d4b6cd). May have CBC data.

**6.8.2 first launch:**
1. `StorageCipherFactory`: no markers → saved = CBC (fallback), current = GCM → `requiresReEncryption()` = true
2. `migrateNonBiometricWithBackup()` runs (because `migrateWithBackup: true`)

**Sub-case A — migration fully succeeds:**
- CBC data decrypted, re-encrypted as GCM, GCM markers written, FSS10 flag written
- No impact

**Sub-case B — migration fails mid-step-5 (partial GCM entries written):**
- Step 3.5 already deleted originals from `FlutterSecureStorage`
- Step 5 wrote SOME entries with new GCM cipher before exception
- `rollbackMigration()` (FSS10@47ad06f) restores `_BACKUP` entries — but **does NOT delete the
  partially-written GCM entries** (this is the bug fixed in 6530bef)
- Post-rollback state in `FlutterSecureStorage`:
  - `_BACKUP`-restored entries (CBC cipher — decryptable with saved cipher)
  - Step-5 GCM entries (new cipher — NOT decryptable with saved CBC cipher)
- FSS10 throws exception, caught by `storage_locator.dart`
- "FSS9 fallback" (actually FSS10 Android with `encryptedSharedPreferences: true`) runs `checkAndMigrateToEncrypted()`:
  - Reads `FlutterSecureStorage` with **current GCM cipher**
  - Successfully reads step-5 GCM entries
  - CBC entries (`_BACKUP`-restored) fail GCM decryption — silently skipped
  - Writes PARTIAL subset to Tink ESP
  - Sets `ENCRYPTED_PREFERENCES_MIGRATED = true`
- "FSS9" `readAll()` returns partial data, FSS9 flag written

**Impact: User sees missing wallets.** Some seeds/keys in the partial GCM subset; others only in the
`_BACKUP`-restored CBC entries that are now stranded in `FlutterSecureStorage` but invisible to
subsequent reads.

Note: FSS10@47ad06f also does NOT clear `ENCRYPTED_PREFERENCES_MIGRATED` on rollback (fixed in
6530bef via the "Step 2.5" addition). If this flag gets set during a partial ESP migration, a
subsequent normal FSS10 launch will try to open ESP, find it empty or partial, and return empty.

---

### Scenario 3: Users who came from ESP-only FSS9

**Pre-state:** `ENCRYPTED_PREFERENCES_MIGRATED` flag exists. Data in Tink ESP.

**6.8.2 first launch:**
1. FSS10 migration triggers (no config markers → CBC→GCM)
2. `migrateNonBiometricWithBackup` step 3: no `_BACKUP` entries in custom cipher SharedPrefs
3. Step 6: `hasDataInEncryptedSharedPreferences` = true → `migrateFromEncryptedSharedPreferences` runs
   — reads all ESP data, encrypts with GCM, writes to custom cipher SharedPrefs
4. Step 7: GCM markers written, `ENCRYPTED_PREFERENCES_MIGRATED` updated
5. `readAll()` succeeds, FSS10 flag written

**Impact: None for these users.** Data fully migrated ESP → GCM. Channel collision irrelevant.

---

### Scenario 4: OAEP / stale AES key (the recovery log user)

**Symptoms observed in the SYSTEMATIC CIPHER RECOVERY log:**
- PKCS1 RSA key exists in Keystore and successfully unwraps the AES blob
- Unwrapped AES key is wrong — GCM decryption fails with `AEADBadTagException`
- All 5 cipher combinations fail

**Root cause:**
During some migration or recovery attempt, `KeyCipherImplementationRSA18()` was constructed (this
happens in `StorageCipherFactory` for attempts 2–5 of the systematic recovery). The constructor
calls `createRSAKeysIfNeeded()`, which **creates a new RSA key pair if the alias is not found**.
This clobbers any existing entry at the same Keystore alias.

A new AES key is then created and wrapped with the new RSA key — but the existing data was
encrypted with the OLD AES key. The old RSA key is gone; the standard alias now holds a new key
pair. PKCS1 unwrap succeeds but produces the wrong AES key. Data is unreadable.

This can happen multiple times if the app is launched repeatedly after the initial corruption —
each systematic recovery run potentially recreates the RSA key yet again.

**Why KEYSTORE_ENUM (ATTEMPT 6) helps:**
KEYSTORE_ENUM enumerates ALL RSA keys in the Android Keystore instead of looking up by hardcoded
alias. It tries to unwrap the known AES blob names with BOTH PKCS1 and OAEP padding for every RSA
key found. It never calls `createRSAKeysIfNeeded()` — it is fully read-only.

If the original RSA key still exists under ANY alias (e.g., a backup system preserved it under a
slightly different name, or it was created under an OAEP alias variant), KEYSTORE_ENUM finds it.

---

## 6. Update Path: 6.8.2 → Latest (6.9.0+)

Latest ships FSS10@6530bef + FSS9@01ed2ee. The Dart import is fixed; FSS9 Dart correctly routes to
FSS9 Android handler (`flutter_secure_storage_legacy`).

| `SeedStoreType` flag after 6.8.2 | What happens on 6.9.0+ first launch | Outcome |
|---|---|---|
| `fss10` | FSS10@6530bef reads GCM, no migration | ✅ Full data |
| `fss9` (full ESP) | FSS9@01ed2ee Android handles ESP reads correctly | ✅ Full data |
| `fss9` (partial ESP, scenario 2B) | FSS9 reads ESP but ESP is incomplete | ⚠️ Missing entries |
| `fss10` but OAEP key issue (scenario 4) | FSS10@6530bef decryption fails | ❌ No wallets visible |
| `null` (6.8.2 crashed before flag write) | FSS10@6530bef first (fixed rollback), FSS9@01ed2ee proper fallback | Depends on data state |

For the scenario 2B case: the `_BACKUP`-restored CBC entries are still sitting in
`FlutterSecureStorage` after the partial migration. Normal 6.9.0+ launch does not read these
(FSS9 opens ESP; FSS10 would need correct GCM key to read custom cipher entries). These entries
are stranded unless the rescue APK reads them.

---

## 7. Rescue APK Assessment

The rescue APK uses `recoveryMode: true` which runs `systematicRecovery()` — reads from
`FlutterSecureStorage` (custom cipher), never opens ESP.

**ATTEMPT sequence:**
1. OAEP+GCM
2. PKCS1+GCM
3. OAEP+CBC
4. PKCS1+CBC
5. Hybrid combinations
6. KEYSTORE_ENUM (new — enumerates all Keystore RSA keys, tries both paddings per key, tries both GCM and CBC per unwrapped AES key)

### Helps

| Case | Which attempt | Why |
|---|---|---|
| Scenario 4 (stale/wrong AES key) | ATTEMPT 6 | Finds the correct RSA key under any alias |
| Scenario 2B (`_BACKUP` CBC entries in FlutterSecureStorage) | ATTEMPT 4 (PKCS1+CBC) | `_BACKUP`-restored entries are still present in custom cipher SharedPrefs with the key prefix; attempts read all prefixed entries including `_BACKUP`-suffixed ones |
| Any user with intact custom cipher data | ATTEMPTs 1–5 | Standard cipher combinations |

### Does NOT help

| Case | Why |
|---|---|
| Data fully moved to ESP, custom cipher SharedPrefs is empty | Recovery mode only reads `FlutterSecureStorage` |
| Data completely deleted or overwritten | Nothing to recover |

### Combined recovery path for scenario 2B

A user with partial migration corruption may need both:
1. **Rescue APK** → reads `_BACKUP`-restored CBC entries from `FlutterSecureStorage` (ATTEMPT 4)
2. **Normal 6.9.0+ launch** → reads partial ESP entries via FSS9@01ed2ee

Together these two paths cover different subsets of the original data. Neither alone is complete.

---

## 8. Key Differences Between FSS10@47ad06f and FSS10@6530bef

| Behaviour | 47ad06f (buggy) | 6530bef (fixed) |
|---|---|---|
| Rollback: clean non-backed-up migration artifacts | ❌ Does not delete step-5 GCM entries written before failure | ✅ Deletes non-backed-up keys during rollback |
| Rollback: clear `ENCRYPTED_PREFERENCES_MIGRATED` | ❌ Flag left set, subsequent ESP path sees "already migrated" | ✅ Clears the flag (Step 2.5 in rollback) |
| `StorageCipherFactory.storeSavedAlgorithms()` | ❌ Method absent | ✅ Present (used in rollback to revert markers) |
| Verbose debug logging | Present (removed in 6530bef) | Removed |

---

## 9. Key Differences Between FSS9@c32db29 and FSS9@01ed2ee

The Java (Android) code is **identical** between the two commits. The only change is in the Dart
layer:

| File | c32db29 | 01ed2ee |
|---|---|---|
| `flutter_secure_storage/lib/flutter_secure_storage.dart` | `import 'package:flutter_secure_storage_platform_interface/...'` | `import 'package:flutter_secure_storage_legacy_platform_interface/...'` |

The Android method channel string in `flutter_secure_storage_platform_interface/lib/src/method_channel_flutter_secure_storage.dart`
(the FSS9 copy) was already `plugins.it_nomads.com/flutter_secure_storage_legacy` at c32db29.
Only the Dart import path was wrong.

---

## 10. KEYSTORE_ENUM Implementation Notes

Added to `FlutterSecureStorage.java` as ATTEMPT 6 in `systematicRecovery()`. Key properties:

- **Read-only:** Never calls `createRSAKeysIfNeeded()`, `KeyCipher.deleteKey()`, or any write to
  SharedPreferences
- **Exhaustive:** Iterates all aliases in Android Keystore, filters to `PrivateKey` entries only
- **Both paddings:** For each RSA key, tries both PKCS1 and OAEP unwrap of each known blob name
- **Both storage ciphers:** For each successfully unwrapped AES key, tries GCM and CBC decryption
- **Backup-aware:** `tryDecryptWithRawAesKey()` handles `_BACKUP`-suffixed data entries
- **Version string:** `systematicRecovery` header updated to `v1.1` to distinguish in logs
