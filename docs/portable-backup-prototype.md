# Portable backup prototype

Branch: `distributed-resiliant-backups`. Standalone entrypoint: `tools/portable_backup_prototype_app.dart`. Explicit demo mode uses public synthetic fixtures; recovery mode does not construct or inject those fixtures. Production wallet storage, metadata encryption/authentication, BIP138/xpub backups and Bitcoin transactions remain unchanged.

## Scope

One BIP85-derived 12-word English BIP39 password unlocks two separate RecoverBull-encrypted files: a complete supported metadata snapshot and a complete BullVault descriptor. Only the vault file can be published on Nostr. A fresh recovery screen takes the password and relay URL, derives the expected author, verifies signed events, and decrypts locally. It also opens a supplied metadata file. Unlocking does not import or overwrite wallets.

This revision replaces the experimental custom age codec with the existing pinned `recoverbull` dependency and its public `RecoverBull.createBackup()` / `RecoverBull.restoreBackup()` APIs, as requested by the user. The adapter handles size bounds, input snapshots and background execution; it does not implement a cipher. No age library or compatibility fallback remains. Old age prototype files can still be recovered with external age tools or the previous commit's harness; this revision uses a distinct profile and does not fetch or open those files.

The metadata fixture includes every supported section and is not an export of this machine's wallet. Its outer network identifies the retrieval context; a snapshot can contain wallets on different networks. Production server upload, existing-user migration, production settings integration, wallet import and password-derived Bitcoin publication/discovery are outside this slice.

## Exact prototype profile

The credential derivation and envelope are a versioned BULL prototype, not a claim of BIP138 wire compatibility or compatibility with legacy metadata credentials.

1. Derive all 64 bytes of BIP85 entropy at the existing reserved path `m/83696968'/1642'/0'/1'`.
2. HKDF-SHA256: input is that entropy, salt is UTF-8 `bullbitcoin-backup-password`, info is UTF-8 `mnemonic-v1`, output length is 16 bytes.
3. Encode those 16 bytes as a valid 12-word English BIP39 mnemonic: 128 bits of entropy plus checksum. Do not truncate the legacy metadata key or generate an unrelated wallet.
4. Require 12 full English words and valid checksum on entry; normalize case and whitespace. Decode the words to their 16 entropy bytes.
5. HKDF-SHA256 with those entropy bytes, the same salt, info `encryption-v1`, output length 32 bytes gives the RecoverBull encryption key. The words represent the recoverable credential; their UTF-8 sentence is not directly passed to AES. This key also serves as the input to the separate Nostr derivation below.
6. Nostr private scalar: HMAC-SHA256 keyed by that 32-byte key, message UTF-8 `nostr-auth-v1`, byte `00`, one counter byte starting at zero. Select the first result strictly between zero and the secp256k1 order, with at most 256 attempts. The author is its x-only public key; BIP340 signing uses no Taproot tweak.

The words and Nostr identity are unchanged from the age experiment. Nostr kind is 1089; tags are exactly `[["d","bullbitcoin-portable-backup-recoverbull-prototype-1"]]`. Content is padded standard base64 of the encrypted bytes. Lookup uses that tag, kind and credential-derived author; it needs no xpub, parent seed or saved event ID. Signatures, expected author and exact profile are checked before decryption. Up to 32 events are returned with partial-result reporting. All authentic candidates remain available; timestamps do not establish which vault is current.

## Encryption bytes

The existing RecoverBull dependency is pinned at `92925c959f219fa4dfd0fe0f40392ddf868e2774` in `pubspec.lock`. Its format is `IV || ciphertext || MAC`:

- IV: 16 fresh random bytes for each file.
- Ciphertext: AES-256-CBC with PKCS7 padding and the 32-byte derived key.
- MAC: HMAC-SHA256 with that same key over `IV || ciphertext`, 32 bytes.

This is the existing library protocol, including its use of the same key for AES and HMAC; this prototype does not redesign it. `restoreBackup()` verifies the MAC before decryption. The library's generated backup ID, salt and creation time are not needed for direct-key decryption and are not serialized here, matching the existing metadata encryptor's ciphertext extraction. Encryption is randomized; credential derivation and recovery are deterministic. A 32-byte derived key does not increase the credential's 128-bit entropy.

For a nonempty plaintext of length N, the file is `48 + 16 * (floor(N / 16) + 1)` bytes: 49–64 bytes overhead. Plaintext is limited to 1MiB; encrypted input to 1MiB + 64 bytes. The authenticated plaintext is gzip-compressed UTF-8 JSON:

```json
{"format":"bullbitcoin-portable-backup-recoverbull-prototype-1","kind":"vault","network":"testnet4","contents":"<complete public multipath descriptor>"}
```

For metadata, `kind` is `metadata` and `contents` is the original canonical snapshot JSON string. Profile, network and kind are authenticated inside the ciphertext and checked after decryption. Expanded plaintext is bounded to 1MiB. The existing BDK parser validates ranged public receive/change descriptors. Publication authenticates and checks the vault kind, then publishes the same snapshotted bytes, preventing accidental metadata publication.

## Public derivation vector

Test seed bytes are `63` repeated 32 times (hex):

- Password: `abandon differ wave love claim impact beach put bunker polar fragile crop`
- BIP39 entropy: `0007bbdfc2329ae384dd761e74ed7199`
- Derived encryption key: `301375cfd80649921db2be0ad3bb812460bf9a712a256de81704f909f84907f3`
- Nostr author: `0e4567d2c920d4bd991a9e472391cc429464f8c621d92c6e87c005800c998c7b`

These and all demo keys are public test data and must never protect real funds or private metadata.

## Recovery without the app

Use the documented BIP39/HKDF derivation and AES-CBC/HMAC layout above with a local implementation, or the pinned RecoverBull library. Verify the MAC before decrypting or accepting any output, remove PKCS7 padding, decompress gzip and parse the JSON. This is not an age file and cannot be opened by the age command.

A bounded local harness reads the backup words from stdin, without logging them or placing them in command-line arguments:

```sh
fvm dart run tools/portable_backup_crypt.dart decrypt vault.bin backup.json.gz
gzip --decompress --stdout backup.json.gz
```

Only generated credentials are supported. Run the harness in a trusted local environment; it is a developer tool and does not provide the mobile app's protected secret-input UI.

## Running and validation

```sh
fvm flutter run -d emulator-5582 --flavor beta -t tools/portable_backup_prototype_app.dart
# Explicit synthetic demo:
fvm flutter run -d emulator-5582 --flavor beta -t tools/portable_backup_prototype_app.dart --dart-define=PORTABLE_BACKUP_DEMO=true
# Actual relay publication, fresh password-only retrieval, and address equivalence:
fvm flutter test integration_test/portable_backup_nostr_test.dart -d emulator-5582 --flavor beta --dart-define=PORTABLE_BACKUP_LIVE=true --reporter expanded
```

Default test relay is `wss://nos.lol`; override with `PORTABLE_BACKUP_RELAY`. The live test requires recovery of the exact newly acknowledged event, complete descriptor equality, receive/change address equality at indices 0, 7 and 111, and local opening of the separate metadata file with the same password. It registers the test text-input client to avoid competing Android IME updates; cryptography, screen protection and Nostr traffic remain real.

Current review and verification results are recorded in [portable-backup-security-review.md](portable-backup-security-review.md). Host and Android builds run separately to avoid native-asset resolution conflicts. This workstation's complete host suite uses `LD_PRELOAD="$PWD/build/native_assets/linux/libbdk_dart_ffi.so" make unit-test`.

## Security boundaries

The password is a bearer credential: sharing it permits decryption of both artifacts and Nostr publication under the backup identity. It does not itself grant Bitcoin signing authority. Parent-seed compromise or weak randomness compromises the derived credential. Nostr's public author provides an offline guess verifier; there is no slow password KDF, and hand-chosen words are unsuitable.

Public events reveal a stable author, publication times and ciphertext sizes. Relays can correlate requests with IP addresses, omit events, forget them or replay authentic older backups. Encryption provides neither rollback protection nor 20-year availability. Cancellation prevents result adoption but cannot stop an already-running worker. WebSocket frames are assembled before application size checks, so those bounds are not a complete transport-memory defense.

Words remain in protected widget input and operation arguments, are cleared on submission and any non-resumed lifecycle state, and are neither logged nor stored in Cubit state. Full metadata plaintext is not retained in UI state. Screen protection fails closed. Dart cannot guarantee secure erasure of immutable strings or runtime copies; this does not protect against OS compromise.
