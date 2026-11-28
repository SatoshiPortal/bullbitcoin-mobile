# secrets

User secret material — BIP39 mnemonics and raw seeds — behind a custody boundary. `Secrets` manages creation, storage and recovery. A `Secret` is a handle for operations on one stored secret; neither object holds mnemonic words or a seed.

Custody owners implement the public `SeedReferencePort`; the application registers every owner before exposing deletion and refuses deletion if any inventory fails or is incomplete.

`ParentCustodyAdmissionPort` is the host's cross-process admission contract for publishing a parent-seed obligation and checking/deleting an unreferenced parent. Secrets supplies the contract only; the wallet owner supplies persistence and policy. Its scoped `ParentCustodyLease` reads `ready`, `deleting` or `deleted`, and commits deletion state independently of the exclusion lease. A callback must publish its durable obligation before returning; fetching a handle alone does not protect a seed. Lease methods refuse use after the callback ends, and an admission budget never truncates admitted work.

The wallet's manual deletion and orphan cleanup both hold this admission through complete reference inventory and `Secrets.trash`. Deletion also requires a tested backup: after the reference inventory and any foreground reconciliation, and before the durable `deleting` marker, the deletion asks the same `InventoryBackupVerification` the inventory opened with — a verified proof deletes, a missing proof refuses with `ParentCustodyBackupRequiredFailure`, and an unreadable one refuses with `ParentCustodyBackupUnavailableFailure`, since unknown is never absent. Keeping a seed is recoverable and deleting its only copy is not, so a refused cleanup leaves the seed and its membership in place. A parent already gone while reconciling a tombstone completes without a proof, because there is nothing left to delete. A deletion interrupted after the durable `deleting` marker remains blocked for automatic cleanup. A new explicit foreground deletion request reconciles the parent with `Secrets.fetch` and complete owner inventory under the same admission; it can complete a deletion already performed or delete a reimported, unreferenced, backed-up parent. An unreadable parent is never treated as absent. These host guarantees do not change `Secrets.trash`, which remains unconditional and knows nothing of wallets.

Explicit mnemonic import learns the parent identity, takes the same admission, re-fetches the seed inside it, derives and publishes the durable wallet catalog/native state, then calls `reconcilePresent`. This deliberate foreground action can clear `deleting` or `deleted`; a missing seed refuses publication. The admission ends before balance reads or network synchronization. Default-wallet creation and startup recovery retain their existing paths; admission protects cooperating publishers rather than claiming to serialize every legacy creator.

`ParentCustodyMetadataFailure` means expected durable state is missing, malformed or incompatible. Import and manual seed deletion refuse with a localized security-metadata message; neither reconstructs `ready` automatically. An explicit foreground repair using a fresh seed read and complete owner inventory remains a follow-up. Other keystore/admission failures remain typed refusals. Tests use injected cutpoints for Dart deletion crash windows; the Python3 child terminated by SIGKILL proves SQLite cross-process exclusion and committed tombstone persistence, not termination of the Dart deletion usecase. Isolate-termination coverage is separately identified.

## Public API

<!-- secrets-api:start -->

Generated from `lib/secrets.dart`; update with `make secrets-api-docs`.

Each asynchronous `Future<Result<T, SecretFailure>>` is shown as `T`. Other returns are unchanged. `name:` denotes a required named argument; brackets denote optional arguments and show explicit defaults. Constructors, static members, Object methods and internal members are omitted. Synchronous capability groups are expanded; data and widget values remain leaves.

```text
Secrets
|-- silentPaymentKeychain
|   |-- readBackend() -> String?
|   |-- writeBackend(value) -> void
|   |-- deleteBackend() -> void
|   |-- readAutoScan() -> String?
|   `-- writeAutoScan(value) -> void
|-- swapKeychain
|   |-- read(key) -> String?
|   |-- write(key, value) -> void
|   `-- delete(key) -> void
|-- generate([wordCount: MnemonicLength.words12]) -> Secret
|-- import(words:, language:, [passphrase:], [acceptOnly:]) -> Secret
|-- fetch(id) -> Secret
|-- list() -> List<SecretEntry>
|-- trash(id) -> void
|-- exists(id) -> bool
|-- contains(words:, language:, [passphrase:]) -> bool
|-- find(words:, language:, [passphrase:]) -> Secret?
|-- preview
|   |-- arkFingerprint(words:) -> Fingerprint
|   |-- bitcoinDescriptors(words:, language:, [passphrase:], network:, scriptTypes:) -> Map<ScriptType, ({String external, String internal})>
|   `-- matchesBitcoinDescriptors(words:, language:, [passphrase:], network:, scriptType:, expected:) -> bool
|-- recoverbull
|   |-- restore(vault:, key:, [passphrase:], [allowUnverified: false]) -> RestoredVault
|   `-- fingerprint(vault:, key:, [passphrase:]) -> Fingerprint
`-- databaseKeys(module:)
    |-- open(name:, file:, [existingSchemaVersion:]) -> Future<Result<QueryExecutor, DatabaseOpenFailure>>
    |-- getOrCreate(name:) -> DatabaseKey
    |-- get(name:) -> DatabaseKey
    `-- reset(name:) -> void
```

```text
Secret
|-- info -> SecretInfo
|-- id -> Fingerprint
|-- derive
|   |-- descriptors
|   |   |-- bitcoin(network:, scriptType:, [accountIndex: 0]) -> Descriptors
|   |   `-- liquid(network:) -> String
|   |-- bip85
|   |   |-- hex(numBytes:, index:) -> String
|   |   `-- mnemonic(wordCount:, index:, language:) -> List<String>
|   |-- xpub(network:, scriptType:, [accountIndex: 0]) -> String
|   `-- swapKey(network:) -> SwapMasterKey
|-- sign
|   |-- psbt(psbt, network:, scriptType:, [accountIndex: 0]) -> String
|   `-- pset(pset, network:) -> String
|-- backup
|   `-- recoverbull([metadata: const {}]) -> ({VaultKey key, EncryptedVault vault})
|-- verify
|   |-- passphrase(candidate) -> bool
|   |-- mnemonic(words) -> bool
|   `-- seed(hex) -> bool
|-- silentPayments
|   `-- account(name:, network:, blindbitUrl:, electrumUrl:, dataDir:, dustLimit:, fetchConcurrencyFactor:, matchConcurrencyFactor:, [headerCheckpoint:]) -> SpAccount
`-- widgets
    |-- mnemonicView([key:], failureBuilder:, [style:], [passphraseLabel:], [passphraseLabelStyle:], [showPassphrase: false], [placeholder: const SizedBox.shrink()], [wordBuilder:], [layoutBuilder:]) -> MnemonicView
    `-- mnemonicChallenge([key:], tileBuilder:, layoutBuilder:, onSolved:, onMistake:, failureBuilder:, [onProgress:], [style:], [placeholder: const SizedBox.shrink()]) -> MnemonicChallenge
```

<!-- secrets-api:end -->

These trees describe the implemented API, not a future specification. The generator follows the exports of `lib/secrets.dart`, including exported extensions and extension types, so a renamed operation or changed default appears without a second method list to maintain. `make secrets-api-docs-check` detects stale trees in `make checks` and CI. Behavioral documentation below remains maintained by the author of the change.

## Getting started

This minimal Flutter entry point creates a secret and derives its testnet account xpub. It uses the real platform keystore and requires the package's native dependencies to be built. Supply an app-owned temporary directory for Liquid signing in the app composition root; the example uses the platform temporary directory. Displaying secret words additionally requires the host's authentication and screen-capture protection.

<!-- secrets-example:start -->
```dart
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart' show SessionAuthority;

Future<Result<String, SecretFailure>> createAccount(Secrets secrets) async {
  switch (await secrets.generate(wordCount: MnemonicLength.words12)) {
    case Ok(:final value):
      return value.derive.xpub(
        network: BitcoinNetwork.testnet,
        scriptType: ScriptType.bip84,
      );
    case Err(:final failure):
      return Err(failure);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The composition shares one authority with the inventory, which grants it
  // after authentication; while it is locked every operation is refused.
  final authority = SessionAuthority();
  final secrets = Secrets(
    scratchDirectory: () async => Directory.systemTemp.path,
    authority: authority,
  );
  final result = await createAccount(secrets);
  runApp(Directionality(
    textDirection: TextDirection.ltr,
    child: Text(switch (result) {
      Ok() => 'Account created',
      Err() => 'Could not create the account',
    }),
  ));
}
```
<!-- secrets-example:end -->

Keep `secret.id`, a `primitives.Fingerprint`, to fetch a new handle later. Import callers supply words once and must release their own copies afterwards; the package does not return those words. `Secret.info` is a metadata snapshot, not a guarantee that a later operation can still read the keystore. Operations re-read their material when needed.

## Lifecycle and listing

`generate` and `import` return a `Secret`. Importing an existing secret returns a dedicated duplicate failure; it never overwrites the existing entry. `contains(words:, language:, passphrase:)` and `exists(id)` are preliminary checks, not proof that a later import or read will succeed. `preview.bitcoinDescriptors(words:, language:, passphrase:, network:, scriptTypes:)` derives the public account-0 descriptors of words that are not stored, one pair per requested script type from a single seed derivation, for a chain scan before import: it reads and writes nothing, keeps nothing, and only descriptor strings leave the isolate that derives and wipes the seed. The words are read in the `language` the caller states, so every mnemonic previews its own seed and the descriptors match those an import of the same words in the same language derives. `trash(id)` deletes the secret; checking whether a wallet still needs it belongs to the application.

`preview.arkFingerprint(words:)` returns the public Bark m/350h consistency identity of an already scoped English child, with the empty passphrase required by existing Ark accounts. It never reads or writes the keystore and returns only a validated `Fingerprint`. The host must pair it with the same child supplied to Bark; the four-byte identity is not cryptographic authentication. Temporary seed bytes are wiped, but library-internal copies cannot be guaranteed erased.

`list()` returns `List<SecretEntry>`. The sealed family contains usable `Secret` handles and `UnreadableSecret` entries carrying their failure and, when recoverable, their fingerprint. A failure to read the store as a whole remains an `Err`; it must not be interpreted as an empty store or a lost seed. On Android, the platform's `readAll` may fail because of an entry in any namespace. Fetching an individual secret avoids that global read.

## Outputs and custody

| Operation | Output | Sensitivity |
|---|---|---|
| `preview.arkFingerprint` (on `Secrets`) | public Bark child fingerprint | 32-bit consistency discriminator, no spending authority |
| `derive.xpub` | account xpub | reveals addresses |
| `preview.bitcoinDescriptors` (on `Secrets`) | receive/change public descriptors of unstored words | reveals addresses |
| `derive.descriptors.bitcoin` | receive/change public descriptors | reveals addresses |
| `derive.descriptors.liquid` | confidential descriptor with its SLIP-77 blinding key | reveals amounts and assets, without spend authority |
| `sign.psbt`, `sign.pset` | signed serialized transaction data | authority for the signed transaction |
| `verify.mnemonic`, `verify.seed` | match or mismatch | no stored material returned |
| `info`, `id` | fingerprint and shape | no key material |
| `derive.bip85.hex`, `derive.bip85.mnemonic` | child entropy or words | spending authority over what the child controls |
| `derive.swapKey` | `SwapMasterKey`, an independent swap credential | spending authority over swaps |
| `backup.recoverbull` | encrypted vault and its separate key | together recover the words; store them apart |
| `silentPayments.account` | a live bwk Silent Payments account that scans and signs | ⚠️ bwk receives the BIP39 seed; its native account retains signing capability until disposed and released |
| `databaseKeys(module:).getOrCreate` | module database key | opens the encrypted database |
| `widgets.mnemonicView`, `widgets.mnemonicChallenge` | sealed widgets and events | words rendered on the protected screen |

The stored words, passphrase, seed and master xprv have no public getter. The grouped interface is the only public spelling. Flat implementation methods and widget constructors are internal; applications cannot call them without an analyzer diagnostic. The three derivation operations returning key material are BIP85 hex, BIP85 mnemonic and the swap master key. `silentPayments.account` returns no material to the app, but its returned account retains keys after the call: bwk-dart opens it from the full BIP39 seed. The temporary Dart copy is wiped after the call; erasure of all bridge and native copies cannot be guaranteed. The Liquid and Boltz adapters also use the full BIP39 seed. Backup keys and database keys are listed separately above.

## Derivation, signing and verification

Account xpub derivation accepts the shared `Network`, either `BitcoinNetwork` or `LiquidNetwork`. Descriptors and signatures remain chain-specific. `accountIndex` defaults to zero and selects the same Bitcoin account for xpub derivation, descriptors and signing. Mnemonic generation and BIP85 mnemonic derivation both use `MnemonicLength` through `wordCount`. BIP85 is independent of the network; the application allocates child indices.

Account xpub derivation, Bitcoin signing, Liquid descriptors and signatures, BIP85 and swap credentials honor the stored passphrase. Legacy passphrase-less Liquid defaults keep the seed lwk's word-based signer derived. A Liquid-network xpub does not necessarily describe the keys in the Liquid descriptor, for example with a different script type. Stored mnemonics support all ten BIP39 languages. Import and word verification normalize words with NFKD; seed derivation normalizes the sentence and passphrase with NFKD. Bitcoin signing constructs its BDK key from the master xprv derived in Dart from that seed. BIP85 takes the child language independently of the parent; the caller states it, and the app's application paths use English children. Silent Payments derives from the full BIP39 seed and honours the stored language and passphrase. The application still selects the default Bitcoin wallet. Default-wallet recovery must retain a passphrase independently from the vault.

Signing takes and returns base64 PSBT/PSET strings. Both chains refuse inputs asking for anything other than `SIGHASH_ALL`. A successful Bitcoin signing call may return a partially signed PSBT, as required by payjoin; success does not imply finalization or readiness to broadcast. The caller supplies required key-origin information and decides whether outputs, fees and inputs are acceptable.

`verify.mnemonic(words)` compares words only. `verify.seed(hex)` compares seed bytes, including the stored passphrase in the derivation for a mnemonic secret. A seed-only secret supports seed verification; mnemonic verification returns `MnemonicRequiredFailure`. A match is `Ok(true)`; a different seed or malformed candidate hex is `Ok(false)`; inability to read or check stored material is an `Err`.

Historical seed-only entries support xpub, Bitcoin descriptor and BIP85 derivation. Operations requiring mnemonic words — the current signers, Liquid descriptors, swap credentials, vault backup and word widgets — return `MnemonicRequiredFailure` for those entries. This is an adapter capability, not a claim that raw seeds cannot sign cryptographically.

## Language persistence and native capabilities

`import(words:, language:, passphrase:)` and `contains` require the BIP39 language of the words; no word-reading API defaults to English. `SecretInfo.language` exposes it as metadata; it is null for a historical raw seed. Storage adds the optional `language` key only for non-English mnemonics. Existing and newly imported English entries retain the original JSON shape and bytes. Unknown stored languages are unreadable entries, never an English fallback. Duplicate detection compares the complete seeds when words, languages or passphrases differ, including equivalent Unicode spellings and shared Chinese words. ⚠️ Words are stored NFKD-decomposed, so Japanese and Korean entries differ from their composed spelling: consumers normalise to NFKD before comparing.

Liquid descriptors and signatures, and the swap key, derive from the BIP39 seed of the words in their own language, so every language gets its own wallets; an English mnemonic gets exactly the keys its words gave before. Silent Payments also derives from that full seed, preserving the account of an English mnemonic without a passphrase.

Import, onboarding and default-wallet recovery offer all ten BIP39 wordlists. The in-app keyboard and suggestions normalize Unicode without exposing words to the platform IME. Detection never silently selects a language; ambiguous sentences require an explicit choice. Generation continues to use the existing English BDK generator.

Sealed display and challenge widgets obtain language in the same read as the words and support all ten lists. Their cells use the dimensions of the entire public wordlist in that language, normalized to NFKD, never those of the actual secret words. Japanese sentence layout uses the ideographic separator. No raw-word getter or semantics exposure is added.

## Recovery and module keys

`secret.backup.recoverbull(metadata:)` returns `({EncryptedVault vault, VaultKey key})`. `EncryptedVault.json` is the encoded document, not a filesystem path. It contains no key. `secrets.recoverbull.restore(vault:, key:, passphrase:)` decrypts and imports the words internally, returning `RestoredVault`: a `Secret` and the caller's metadata. Restoring a vault whose secret already exists returns the existing handle, described with that entry's own language even when the vault's differs; direct `import` remains strict about duplicates. Every new RecoverBull vault stores its language in the reserved `mnemonicLanguage` plaintext field spelled as bip39's `Language.label`, including `english`. Historical keyless vaults restore as English unchanged. Open, restore and fingerprint inspection honor it; unknown values return `InvalidVaultFailure`. Caller metadata cannot override `mnemonic` or `mnemonicLanguage` and is snapshotted before the keystore read; a historical caller `language` key stays free and is returned untouched. The vault contains no passphrase; supply one separately when restoring a passphrase-protected Bitcoin wallet. The passphrase is supplied separately and verified against the vault key before import.

`secrets.recoverbull.fingerprint(vault:, key:, passphrase:)` checks the candidate against the derived vault key and returns its fingerprint without accessing the keystore. It never trusts a fingerprint in metadata and never imports a temporary secret. Explicitly allowing an unverified empty-passphrase sibling does not certify the backup. The vault encryption key is derived from the original secret, including its passphrase, even though the encrypted payload contains words and their language without the passphrase.

`secrets.databaseKeys(module:)` scopes `getOrCreate(name:)`, `get(name:)` and `reset(name:)` to one module. Inject that handle instead of all of `Secrets`. Creation is serialized within the isolate and occurs only on a clean miss; corrupt entries are never replaced automatically. `get` never creates, and `reset` deletes without regeneration. The module owner must also discard the database encrypted by a reset key.

For Drift workers, capture `Secrets.databaseOpener` on the root isolate. It binds the database name, module, file and expected schema without transferring keys or a live connection. The worker initializes the keystore bridge and returns only a keyed executor or a caller-supplied failure. The owner still controls admission and verifies its readiness receipt before exposing the database.

## Sealed widgets and failures

The host styles the sealed word widgets with `wordBuilder` or `tileBuilder` and arranges them with `layoutBuilder`. `failureBuilder(context, failure, retry)` renders an error and can offer a new read after the keystore unlocks. The challenge reports `onSolved`, `onMistake` and `onProgress`; completing the selection is distinct from successful verification. A keystore failure is never reported as a wrong answer. The host supplies localized messages and owns authentication and capture protection around the screen.

Every asynchronous operation returns `Result<T, SecretFailure>`. Handle failure values at the caller's boundary; do not display diagnostic strings directly. A locked keystore is distinct from a missing secret. Programmer misuse such as a malformed database-key segment remains an `ArgumentError`. Strict value constructors validate their input separately from the asynchronous operation.

`Secrets` and `Secret` cannot be mocked by implementing their classes. Tests install the in-memory keystore from `package:secrets/testing.dart` below the real API. Use it only from test code. The package invariant suite rejects testing imports in its own production sources; the CI import gate and local Dart `make custody-check` reject testing imports, exports and resolved test-support symbols in application and workspace production code.

## Boundary checks and remaining migration

`make custody-ci-check` checks keystore access and the internal seal in CI. Local `make custody-check` resolves production Dart symbols to reject private-key derivation and vault decryption outside this package. Node-based custody and PR governance checks run only in CI; local `make checks` requires Dart/Flutter only. Swap-scoped credentials and the public-only xpub decoding adapter have explicit named exceptions; pre-import scanning needs none, since it receives public descriptors from `secrets.preview`. BIP85 child formatting and public-key operations remain allowed. This detects forbidden library operations; it is not a complete information-flow proof.

RecoverBull creation, restoration and backup inspection use the package. Decrypted vaults and their mnemonic no longer reach app presentation state. The app still receives the documented BIP85 children, swap credential, recovery key and database keys.

## Read next

[doc/design.md](doc/design.md): contracts, passphrase behavior, storage ownership, module layout, custody checks and contributor rules.

## Legacy owner keychains

`Secrets.silentPaymentKeychain` and `swapKeychain` expose closed handles. The legacy Exchange records are read only during migration under an exclusive admission. The PIN entries have no runtime capability: the access verifier lives in the inventory, and the legacy entries are read only by the import and the retirement. All operations return `Result<…, SecretFailure>`. Silent Payments owns only its backend and auto-scan settings. Swaps accepts only full legacy `swap_` keys, including `swap_regtest_`, and rejects other namespaces before storage access. No capability lists the keychain or accepts a caller-selected prefix.

The explicit legacy PIN key allowance is `securityKey`. The remaining fixed keys are `failedUnlockAttemptsKey`, `unlockLockedUntilKey`, `exchange_api_key`, `exchange_api_key_testnet`, `sp_backend_config` and `sp_auto_scan_enabled`. The handles access these entries in place with Android `resetOnError: false` and `migrateOnAlgorithmChange: false`, and iOS `first_unlock_this_device`. Moving SP configuration to another store would require a separate migration. Exchange owns its diagnostics without duplicate keychain reporting.

## Encrypted wallet inventory

`SecretsInventory.foregroundSession` in `package:secrets/storage.dart` lets composition capture the live grant, check it synchronously and observe replacement or revocation without granting or revoking access. `listDescriptorsFor` refuses missing or stale authorization rather than reading from whichever view is now active. A token from another authority cannot authorize a read, even for the same view and generation. Background descriptors still use their separate persisted grants.

The Secrets schema owns wallet definitions, BIP85 derivation records and access views. `package:secrets/migration.dart` supplies the foreground participant for split-v1. It copies the inventory from a read-only schema-16 snapshot and verifies every destination value before committing its receipt in `access_state`. A wallet marked local keeps its expected seed fingerprint even when the seed cannot be read. Descriptor spelling, nullable labels and unknown legacy enum text survive the copy.

When the source contains wallets, an existing PIN becomes a salted Argon2id verifier and the failed-attempt count and lockout are copied in the same transaction. An inventory initialized without wallets starts unprotected, including after an iOS reinstall where the keychain can survive the app container. The importer skips malformed seed keys and leaves the receipt pending when the keystore listing is unavailable. It retains the legacy file and keychain entries for coordinated retirement after all owners verify their data.

On the first foreground open of an inventory admitted by an older build, Secrets reconciles access before publishing a session. A legacy PIN takes precedence for an older imported inventory until the access receipt records the handover. A fresh receipt never imported a credential, so a PIN already registered in that inventory takes precedence. If the legacy PIN is absent, an existing inventory credential stays in force. Reconciliation preserves the greater failed-attempt count and deadline when importing legacy protection. A failed read blocks startup and leaves the receipt retryable. The receipt records the handover without deleting the legacy keys, so a PIN removed after the handover stays removed on restart.

The storage library opens an existing admitted inventory. Its foreground capability checks the session before reading or mutating wallet registrations and rechecks the session before returning data. Locking withdraws inventory access. Credential checks and attempt updates share one transaction. PIN retries honor both the persisted deadline and a monotonic delay of 30 seconds per failure beyond the third. After reopening, the full delay for the persisted attempt count starts at the first access check. Protecting an unprotected view requires a tested backup for every secret member, regardless of wallet defaults or active network; a watch-only-only view needs no seed proof. A membership owes that proof while it holds a stored secret, even with no wallet, and while any locally signing wallet still references it, even with no stored secret — the latter is a seed to recover, not a leftover. A membership with neither is what removing the last wallet leaves behind, since deleting the seed keeps the view's `secret:` entry, and it owes nothing, so it cannot block a PIN. Each member is read on its own, so an unrelated unreadable entry cannot decide it, and a keystore or inventory that cannot be read is unknown, never absent. A secret published by a registration always owes a proof, whether or not the view already lists its `secret:` membership and whether or not its words are stored: a leftover membership is not evidence of a backup, so presence cannot decide it. Only a seed another locally signing wallet holds is already protected, and a second wallet of it adds no seed. That check runs before any wallet or property is published. The inventory uses the verifier bound at composition, and changing an existing PIN does not require a new proof. Before preparing wallet properties in a protected view, it checks the backup evidence that will survive replacing that wallet's usage record; it refuses to destroy an existing proof, while a legacy unbacked member can still gain another wallet. An unreadable proof fails closed. A protected watch-only view is not thereby considered backed up. The active view's background grant controls a separate descriptor-only capability for sync.

The host gives features the read-only `WalletInventory` from `package:secrets/secrets.dart`, implemented by the admitted `SecretsInventory`. A targeted lookup distinguishes a wallet not visible to this view, unreadable metadata and a storage read failure. The concrete chain and network come from storage, not from the derivation path or the app's current environment. Network selection returns readable wallets in wallet ID order and their explicit defaults; it neither chooses a fallback nor resolves competing defaults. These reads never expose descriptors. The descriptor catalog for native Sync remains a separate projection, not a metadata lookup for features.

Reserve BIP85 indices per parent and application before deriving the child. Keep every reservation, including revoked entries, so a retry cannot return the same child. Historical paths retain their original spelling.


### Recorded BIP85 derivations

The authorized inventory opens a `Bip85Derivations` capability via `inventory.bip85(secrets)`. Its `list()` returns metadata for all recorded children in the active view, including revoked entries. Deriving a new child reserves a distinct index in the encrypted inventory before deriving it. `reveal(parent)` checks stored paths and returns only the derived children of that parent. The BIP85 root stays in Secrets and an inventory lock invalidates in-flight results.
