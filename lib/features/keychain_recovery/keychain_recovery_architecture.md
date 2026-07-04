# Keychain Recovery Architecture

## Scope

`keychain_recovery` restores supported wallet materializations from validated
`keychain_manifest` import plans. Its domain use case coordinates local wallet
creation/reuse through deterministic wallet public APIs and records restored
materializations through `keychain_manifest/public`; its data implementation
adapts deterministic wallet materialization.

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
- `keychain_recovery -> core/wallet` (re-applies the locked hidden + autosweep
  Get Paid posture to restored wallets via ApplyWalletBehaviorDefaultsUsecase -
  decision [1]/[C]/KC-6)

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
- `skippedUnsupported`
- `failedParentFingerprintMismatch`
- `failedChildSeedFingerprintMismatch`
- `failedInvalidImportPlan`
- `failedWalletCreation`
- `failedManifestRecord`
- `failedConflict`

Unsupported wallet networks do not invalidate the whole manifest file or the
whole entry; supported wallet materializations continue and unsupported ones are
reported per wallet. Invalid manifest file structure, duplicate wallet
materializations, and reservation mismatches are rejected before recovery by
`keychain_manifest`. Because import-plan DTOs cross a public facade boundary,
`keychain_recovery` also revalidates reservation identity, derivation path,
entry identity, and wallet membership before materializing wallets.

Once a wallet materialization is returned as `created` or `alreadyPresent`, it
is treated as current local wallet inventory. If manifest recording then fails,
recovery returns `failedManifestRecord` for those wallets and leaves local wallet
state intact for retry. Rollback is only allowed inside the deterministic wallet
materializer before any wallet is reported as successfully materialized, for
batch-level validation failures such as fingerprint mismatch or wallet-id
conflict.
