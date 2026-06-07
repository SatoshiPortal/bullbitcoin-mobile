# Keychain Recovery Architecture

## Scope

`keychain_recovery` restores supported wallet materializations from validated
`keychain_manifest` import plans. It is a neutral orchestration boundary: it
creates or reuses local wallets through deterministic wallet public APIs and
records restored materializations through `keychain_manifest/public`.

It does not decode manifest files, own manifest persistence, publish or fetch
remote manifests, submit product descriptors, mark product accounts connected,
or expose UI.

## Boundaries

- `keychain_manifest` owns manifest records, file encode/decode validation, and
  import plans.
- `bip85_registry` owns reserved derivation aliases used to reproduce product
  BIP85 children without importing product features.
- `keychain_recovery` owns local wallet materialization restore orchestration.
- `deterministic_wallets` owns BIP85 child mnemonic wallet creation/reuse.
- Product features own product state. Restoring a BTCPay wallet materialization
  restores local wallets only; it does not restore SamRock pairing.

Allowed dependencies:

- `keychain_recovery -> keychain_manifest/public`
- `keychain_recovery -> bip85_registry/public`
- `keychain_recovery -> deterministic_wallets/public`
- `keychain_recovery -> core/settings`

Forbidden dependencies:

- `keychain_manifest -> keychain_recovery`
- `keychain_recovery -> btcpay`
- `keychain_recovery -> get_paid`
- `keychain_recovery -> nostr`
- `keychain_recovery -> UI features`

## Result Model

Restore returns one outcome per wallet materialization:

- `created`
- `alreadyPresent`
- `metadataRepaired`
- `skippedUnsupported`
- `failedParentFingerprintMismatch`
- `failedChildSeedFingerprintMismatch`
- `failedWalletCreation`
- `failedManifestRecord`
- `failedConflict`

`metadataRepaired` only means an already-present verified wallet received a
missing keychain manifest materialization record. It does not repair descriptors,
labels, product accounts, or pairing state.

Unsupported wallet networks do not invalidate the whole manifest file or the
whole entry; supported wallet materializations continue and unsupported ones are
reported per wallet. Invalid manifest file structure, duplicate wallet
materializations, and reservation mismatches are rejected before recovery by
`keychain_manifest`.
