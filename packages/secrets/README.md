# secrets

User secret material — BIP39 mnemonics and raw seeds — behind a custody boundary. `Secrets` manages creation, storage and recovery. A `Secret` is a handle for operations on one stored secret; neither object holds mnemonic words or a seed.

## Public API

<!-- secrets-api:start -->

Generated from `lib/secrets.dart`; update with `make secrets-api-docs`.

Each asynchronous `Future<Result<T, SecretFailure>>` is shown as `T`. Other returns are unchanged. `name:` denotes a required named argument; brackets denote optional arguments and show explicit defaults. Constructors, static members, Object methods and internal members are omitted. Synchronous capability groups are expanded; data and widget values remain leaves.

```text
Secrets
|-- generate([wordCount: MnemonicLength.words12]) -> Secret
|-- generateEphemeral([wordCount: MnemonicLength.words24]) -> EphemeralMnemonic
|-- import(words:, [language: Language.english], [passphrase:], [acceptOnly:]) -> Secret
|-- retainCanonical(id) -> Secret
|-- fetch(id) -> Secret
|-- list() -> List<SecretEntry>
|-- trash(id) -> void
|-- exists(id) -> bool
|-- contains(words:, [language: Language.english], [passphrase:]) -> bool
|-- preview
|   |-- bitcoinDescriptors(words:, [language: Language.english], [passphrase:], network:, scriptTypes:) -> Map<ScriptType, ({String external, String internal})>
|   `-- account(words:, [language: Language.english], derivationPath:, network:, [passphrase: '']) -> PublicAccountKey
|-- recoverbull
|   |-- restore(vault:, key:, [passphrase:]) -> RestoredVault
|   `-- fingerprint(vault:, key:) -> Fingerprint
`-- databaseKeys(module:)
    |-- getOrCreate(name:) -> DatabaseKey
    |-- get(name:) -> DatabaseKey
    `-- reset(name:) -> void
```

```text
Secret
|-- info -> SecretInfo
|-- id -> Fingerprint
|-- derive
|   |-- nostrPublicKey(identity:) -> String
|   |-- descriptors
|   |   |-- bitcoin(network:, scriptType:, [accountIndex: 0]) -> Descriptors
|   |   `-- liquid(network:) -> String
|   |-- bip85
|   |   |-- hex(numBytes:, index:) -> String
|   |   `-- mnemonic(wordCount:, index:, [language: Language.english]) -> List<String>
|   |-- account(derivationPath:, network:, [passphrase:]) -> PublicAccountKey
|   |-- xpub(network:, scriptType:, [accountIndex: 0]) -> String
|   `-- swapKey(network:) -> SwapMasterKey
|-- sign
|   |-- psbt(psbt, network:, scriptType:, [accountIndex: 0]) -> String
|   |-- descriptorPsbt(psbt, descriptor:, network:, keys:, [passphrase:], [signWithTapInternalKey: false]) -> String
|   `-- pset(pset, network:) -> String
|-- backup
|   |-- data() -> BackupCredential
|   |-- recoverbull([metadata: const {}]) -> ({VaultKey key, EncryptedVault vault})
|   `-- recoverbullKey(vault:) -> VaultKey
|-- verify
|   |-- mnemonic(words) -> bool
|   `-- seed(hex) -> bool
|-- silentPayments
|   `-- account(name:, network:, blindbitUrl:, electrumUrl:, dataDir:, dustLimit:, fetchConcurrencyFactor:, matchConcurrencyFactor:, [headerCheckpoint:]) -> SpAccount
`-- widgets
    |-- nostrKey([key:], identity:, publicKey:, qrForeground:, qrBackground:, builder:, failureBuilder:, [style:], [placeholder: const SizedBox.shrink()]) -> NostrKeyView
    |-- dataRecoveryWords([key:], failureBuilder:, [style:], [placeholder: const SizedBox.shrink()], [wordBuilder:], [layoutBuilder:]) -> MnemonicView
    |-- mnemonicView([key:], failureBuilder:, [style:], [passphraseLabel:], [passphraseLabelStyle:], [placeholder: const SizedBox.shrink()], [wordBuilder:], [layoutBuilder:]) -> MnemonicView
    `-- mnemonicChallenge([key:], tileBuilder:, layoutBuilder:, onSolved:, onMistake:, failureBuilder:, [onProgress:], [style:], [placeholder: const SizedBox.shrink()]) -> MnemonicChallenge
```

<!-- secrets-api:end -->

These trees describe the implemented API, not a future specification. The generator follows the exports of `lib/secrets.dart`, including exported extensions and extension types, so a renamed operation or changed default appears without a second method list to maintain. `make secrets-api-docs-check` detects stale trees in `make checks` and CI. Behavioral documentation below remains maintained by the author of the change.

Explicit account derivation returns the actual master fingerprint and the canonical network xpub at the requested path. Its optional passphrase, and the one on descriptor signing, apply only to that operation: omit it to use the stored passphrase, or pass an empty string to use the mnemonic alone. Neither changes the stored secret. Raw seeds accept an empty override but cannot take a BIP39 passphrase.

Descriptor signing verifies each selected account xpub before deriving its private key. It adds partial signatures only; the wallet owns public policy checks, signing-path selection and finalization. Private descriptors and native signing handles are released within the call.

`preview.account` derives public account information from user-supplied words without importing them. `generateEphemeral` creates an independent mnemonic for a bounded setup flow, accessible only through the same sealed display and challenge widgets as stored secrets. The caller must dispose that handle when setup ends. `retainCanonical` retains a words-only sibling of a verified stored mnemonic without replacing its original passphrase entry; callers use it only after establishing ownership of the corresponding public key.

## Getting started

This minimal Flutter entry point creates a secret and derives its testnet account xpub. It uses the real platform keystore and requires the package's native dependencies to be built. Supply an app-owned temporary directory for Liquid signing in the app composition root; the example uses the platform temporary directory. Displaying secret words additionally requires the host's authentication and screen-capture protection.

<!-- secrets-example:start -->
```dart
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

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
  final secrets = Secrets(scratchDirectory: () async => Directory.systemTemp.path);
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

`generate` and `import` return a `Secret`. Importing an existing secret returns a dedicated duplicate failure; it never overwrites the existing entry. `contains(words:, language:, passphrase:)` and `exists(id)` are preliminary checks, not proof that a later import or read will succeed. `preview.bitcoinDescriptors(words:, language:, passphrase:, network:, scriptTypes:)` derives the public account-0 descriptors of words that are not stored, one pair per requested script type from a single seed derivation, for a chain scan before import: it reads and writes nothing, keeps nothing, and only descriptor strings leave the isolate that derives and wipes the seed. The words are read in `language`, English by default, so a non-English mnemonic previews its own seed and the descriptors match those an import of the same words in the same language derives. `trash(id)` deletes the secret; checking whether a wallet still needs it belongs to the application.

`list()` returns `List<SecretEntry>`. The sealed family contains usable `Secret` handles and `UnreadableSecret` entries carrying their failure and, when recoverable, their fingerprint. A failure to read the store as a whole remains an `Err`; it must not be interpreted as an empty store or a lost seed. On Android, the platform's `readAll` may fail because of an entry in any namespace. Fetching an individual secret avoids that global read.

## Outputs and custody

| Operation | Output | Sensitivity |
|---|---|---|
| `derive.xpub` | account xpub | reveals addresses |
| `preview.bitcoinDescriptors` (on `Secrets`) | receive/change public descriptors of unstored words | reveals addresses |
| `derive.account`, `preview.account`, `EphemeralMnemonic.account` | public account key and origin | reveals addresses; no private material returned |
| `derive.descriptors.bitcoin` | receive/change public descriptors | reveals addresses |
| `derive.descriptors.liquid` | confidential descriptor with its SLIP-77 blinding key | reveals amounts and assets, without spend authority |
| `sign.psbt`, `sign.descriptorPsbt`, `sign.pset` | signed serialized transaction data | authority for the signed transaction |
| `verify.mnemonic`, `verify.seed` | match or mismatch | no stored material returned |
| `info`, `id` | fingerprint and shape | no key material |
| `derive.bip85.hex`, `derive.bip85.mnemonic` | child entropy or words | spending authority over what the child controls |
| `derive.swapKey` | `SwapMasterKey`, an independent swap credential | spending authority over swaps |
| `backup.recoverbullKey` | verified key for an existing vault | same recovery credential, derived without storage writes |
| `backup.recoverbull` | encrypted vault and its separate key | together recover the words; store them apart |
| `silentPayments.account` | a live bwk Silent Payments account that scans and signs | ⚠️ bwk receives the stored words and holds them while the account lives; the app gets the account only |
| `databaseKeys(module:).getOrCreate` | module database key | opens the encrypted database |
| `widgets.mnemonicView`, `widgets.mnemonicChallenge` | sealed widgets and events | words rendered on the protected screen |
| `generateEphemeral` | disposable mnemonic handle | independent words stay inside the package and are never stored |
| `retainCanonical` | stored words-only `Secret` handle | retains a backing secret without exposing its words |

The stored words, passphrase, seed and master xprv have no public getter. The grouped interface is the only public spelling. Flat implementation methods and widget constructors are internal; applications cannot call them without an analyzer diagnostic. The three derivation operations returning key material are BIP85 hex, BIP85 mnemonic and the swap master key. `silentPayments.account` returns no material to the app, but its returned account retains keys after the call: bwk-dart opens it from a mnemonic only. The Liquid and Boltz adapters also use English words transiently in the pinned SDK. Backup keys and database keys are listed separately above.

`backup.data()` returns an operation-scoped encryption and signing capability for
public metadata. Private keys remain inside that capability; only ciphertext,
plaintext metadata, public keys and signatures leave it. Recovery can construct
the same capability from user-entered Data Recovery Words without a stored seed.
`widgets.dataRecoveryWords` paints the index-100 child inside the sealed mnemonic
view; the host receives widgets only and must enable capture protection before
mounting it. `derive.nostrPublicKey` returns only a user identity's public key and
rejects application-reserved indices.

## Derivation, signing and verification

Account xpub derivation accepts the shared `Network`, either `BitcoinNetwork` or `LiquidNetwork`. Descriptors and signatures remain chain-specific. `accountIndex` defaults to zero and selects the same Bitcoin account for xpub derivation, descriptors and signing. Mnemonic generation and BIP85 mnemonic derivation both use `MnemonicLength` through `wordCount`. BIP85 is independent of the network; the application allocates child indices.

Account xpub derivation, Bitcoin signing, Liquid descriptors and signatures, BIP85 and swap credentials honor the stored passphrase. Existing Liquid wallets are passphrase-less defaults, for which this is the seed lwk's word-based signer derived. A Liquid-network xpub does not necessarily describe the keys in the Liquid descriptor, for example with a different script type. Stored mnemonics support all ten BIP39 languages. Import and word verification normalize words with NFKD; seed derivation normalizes the sentence and passphrase with NFKD. Bitcoin signing constructs its BDK key from the master xprv derived in Dart from that seed. BIP85 takes the child language independently of the parent; the default remains English. Silent Payments cannot honour a passphrase — bwk derives from the words alone — so `silentPayments.account` refuses a secret that has one with `PassphraseUnsupportedFailure`.

Signing takes and returns base64 PSBT/PSET strings. Standard Bitcoin and Liquid signing accept `SIGHASH_ALL`; descriptor signing also accepts Taproot `SIGHASH_DEFAULT`. A successful Bitcoin signing call may return a partially signed PSBT, as required by payjoin; success does not imply finalization or readiness to broadcast. The caller supplies required key-origin information and decides whether outputs, fees and inputs are acceptable.

`verify.mnemonic(words)` compares words only. `verify.seed(hex)` compares seed bytes, including the stored passphrase in the derivation for a mnemonic secret. A seed-only secret supports seed verification; mnemonic verification returns `MnemonicRequiredFailure`. A match is `Ok(true)`; a different seed or malformed candidate hex is `Ok(false)`; inability to read or check stored material is an `Err`.

Historical seed-only entries support public-account, xpub, Bitcoin descriptor and BIP85 derivation, plus `sign.descriptorPsbt`. Operations requiring mnemonic words, including `sign.psbt`, `sign.pset`, Liquid descriptors, swap credentials, vault backup and word widgets, return `MnemonicRequiredFailure` for those entries.

## Language persistence and native capabilities

`import(words:, language:, passphrase:)` and `contains` use the explicitly supplied BIP39 language, English by default. `SecretInfo.language` exposes it as metadata; it is null for a historical raw seed. Storage adds the optional `language` key only for non-English mnemonics. Existing and newly imported English entries retain the original JSON shape and bytes. Unknown stored languages are unreadable entries, never an English fallback. Duplicate detection compares the complete seeds when words, languages or passphrases differ, including equivalent Unicode spellings and shared Chinese words. ⚠️ Words are stored NFKD-decomposed, so Japanese and Korean entries differ from their composed spelling: consumers normalise to NFKD before comparing.

Liquid descriptors and signatures, and the swap key, derive from the BIP39 seed of the words in their own language, so every language gets its own wallets; an English mnemonic gets exactly the keys its words gave before. Silent Payments still returns `LanguageUnsupportedFailure` for a non-English mnemonic before any native call: bwk builds an account from English words only, until it takes keys ([bwk-bitcoin/bwk#114](https://github.com/bwk-bitcoin/bwk/pull/114)).

The import picker offers English, Spanish, French, Italian, Czech and Portuguese for a separate, non-default Bitcoin wallet. Non-Latin lists stay hidden until a dedicated keyboard is available; the custody API still supports all ten. The in-app keyboard and suggestions normalize Unicode without exposing words to the platform IME. Detection never silently selects a language; ambiguous sentences require an explicit choice. Onboarding and default-wallet recovery remain English-only. Generation continues to use the existing English BDK generator.

Sealed display and challenge widgets obtain language in the same read as the words and support all ten lists. Their cells use the dimensions of the entire public wordlist in that language, normalized to NFKD, never those of the actual secret words. Japanese sentence layout uses the ideographic separator. No raw-word getter or semantics exposure is added.

## Recovery and module keys

`secret.backup.recoverbull(metadata:)` returns `({EncryptedVault vault, VaultKey key})`. `EncryptedVault.json` is the encoded document, not a filesystem path. It contains no key. `secrets.recoverbull.restore(vault:, key:, passphrase:)` decrypts and imports the words internally, returning `RestoredVault`: a `Secret` and the caller's metadata. Restoring a vault whose secret already exists returns the existing handle, described with that entry's own language even when the vault's differs; direct `import` remains strict about duplicates. Every new RecoverBull vault stores its language in the reserved `mnemonicLanguage` plaintext field spelled as bip39's `Language.label`, including `english`. Historical keyless vaults restore as English unchanged. Open, restore and fingerprint inspection honor it; unknown values return `InvalidVaultFailure`. Caller metadata cannot override `mnemonic` or `mnemonicLanguage` and is snapshotted before the keystore read; a historical caller `language` key stays free and is returned untouched. The vault contains no passphrase; supply one separately when restoring a passphrase-protected Bitcoin wallet. The app's default wallets never have a passphrase.

`secret.backup.recoverbullKey(vault:)` derives at the existing file’s recorded BIP85 path and authenticates its mnemonic payload before returning the key. It honors the stored passphrase, accepts historical hardened and unhardened backup indices, and neither imports words nor changes storage. A missing or unsupported path returns `InvalidVaultPathFailure`; a file that does not open returns `InvalidVaultFailure`.

`secrets.recoverbull.fingerprint(vault:, key:)` derives the fingerprint of the decrypted words without a passphrase and without accessing the keystore. It never trusts a fingerprint in metadata and never imports a temporary secret. The result can differ from the original secret's fingerprint when that secret had a passphrase. The vault encryption key is derived from the original secret, including its passphrase, even though the encrypted payload contains words and their language without the passphrase.

`secrets.databaseKeys(module:)` scopes `getOrCreate(name:)`, `get(name:)` and `reset(name:)` to one module. Inject that handle instead of all of `Secrets`. Creation is serialized within the isolate and occurs only on a clean miss; corrupt entries are never replaced automatically. `get` never creates, and `reset` deletes without regeneration. The module owner must also discard the database encrypted by a reset key.

## Sealed widgets and failures

The host styles the sealed word widgets with `wordBuilder` or `tileBuilder` and arranges them with `layoutBuilder`. `failureBuilder(context, failure, retry)` renders an error and can offer a new read after the keystore unlocks. The challenge reports `onSolved`, `onMistake` and `onProgress`; completing the selection is distinct from successful verification. A keystore failure is never reported as a wrong answer. The host supplies localized messages and owns authentication and capture protection around the screen.

Every asynchronous operation returns `Result<T, SecretFailure>`. Handle failure values at the caller's boundary; do not display diagnostic strings directly. A locked keystore is distinct from a missing secret. Programmer misuse such as a malformed database-key segment remains an `ArgumentError`. Strict value constructors validate their input separately from the asynchronous operation.

`Secrets` and `Secret` cannot be mocked by implementing their classes. Tests install the in-memory keystore from `package:secrets/testing.dart` below the real API. Use it only from test code. The package invariant suite rejects testing imports in its own production sources; the CI import gate and local Dart `make custody-check` reject testing imports, exports and resolved test-support symbols in application and workspace production code.

## Boundary checks and remaining migration

`make custody-ci-check` checks keystore access and the internal seal in CI. Local `make custody-check` resolves production Dart symbols to reject private-key derivation and vault decryption outside this package. Node-based custody and PR governance checks run only in CI; local `make checks` requires Dart/Flutter only. Swap-scoped credentials and the public-only xpub decoding adapter have explicit named exceptions; pre-import scanning needs none, since it receives public descriptors from `secrets.preview`. BIP85 child formatting and public-key operations remain allowed. This detects forbidden library operations; it is not a complete information-flow proof.

RecoverBull creation, restoration and backup inspection use the package. Decrypted vaults and their mnemonic no longer reach app presentation state. The app still receives the documented BIP85 children, swap credential, recovery key and database keys.

## Read next

[doc/design.md](doc/design.md): contracts, passphrase behavior, storage ownership, module layout, custody checks and contributor rules.

Nostr private-key display uses `secret.widgets.nostrKey`: the host supplies its public record, warning and capture protection. Secrets verifies the derived public key and renders the private text and QR internally. Only the explicit copy action writes the nsec to the clipboard. Identities 100 and 101 derive from Data Recovery Words; user identities derive from the stored secret.
