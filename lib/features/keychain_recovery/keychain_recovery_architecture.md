# Keychain Recovery Architecture

## Scope

`keychain_recovery` restores supported wallet materializations from validated `keychain_manifest` import plans.
Its domain use case coordinates local wallet creation/reuse through deterministic wallet public APIs and records restored materializations through `keychain_manifest/public`; its data implementation adapts deterministic wallet materialization.

It does not decode manifest files, own manifest persistence, publish or fetch remote manifests, submit product descriptors, mark product accounts connected, or expose UI.

V1 recovery is limited to wallet materializations whose reservation is already manifest-enabled.
BTCPay and Lightning Address wallet materializations can be recovered locally.
Payment Page and Nostr reservations are not recovered or activated by this feature until their owning flows explicitly add support.

Which reserved seeds are exportable vs recoverable at this stack level is the
`KeychainManifestReservationSupport` classification (`supportsV1Export` vs
`supportsV1Recovery`): 100/101/102 are exported into the backup, but only
BTCPay (100) is recovered here because remote recovery is dormant/unwired.
PR23 FORWARD-OBLIGATION (DG-3): when PR23 wires the recovery UI it must flip
`recoverableV1` for the bullnym-backed products (101/102, and 103/POS once
reserved), implement the DG-3 auto-heal (seed-npub lookup + reregister-if-
missing) for them, and re-apply the KC-6 hidden+autosweep posture to those
newly recoverable products. See the classification file for details.

## Boundaries

- `keychain_manifest` owns manifest records, file encode/decode validation, and import plans.
- `bip85_registry` owns reserved derivation aliases used to reproduce product BIP85 children without importing product features.
- `keychain_recovery` owns local wallet materialization restore orchestration.
- `deterministic_wallets` owns BIP85 child mnemonic wallet creation/reuse.
- Product features own product state.
Restoring a BTCPay wallet materialization restores local wallets only; it does not restore SamRock pairing.
Restoring a Lightning Address wallet materialization restores local wallets only; its reservation is marked as `requiresProductReactivation` because Bullnym registration must be checked or recreated by Lightning Address.

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
- `requiresProductReactivation`
- `skippedUnsupported`
- `failedParentFingerprintMismatch`
- `failedChildSeedFingerprintMismatch`
- `failedInvalidImportPlan`
- `failedWalletCreation`
- `failedManifestRecord`
- `failedConflict`

Unsupported wallet networks do not invalidate the whole manifest file or the whole entry; supported wallet materializations continue and unsupported ones are reported per wallet.
Invalid manifest file structure, duplicate wallet materializations, and reservation mismatches are rejected before recovery by `keychain_manifest`.
Because import-plan DTOs cross a public facade boundary, `keychain_recovery` also revalidates reservation identity, derivation path, entry identity, and wallet membership before materializing wallets.

`requiresProductReactivation` is a successful local wallet restore with a required follow-up product activation step.
Lightning Address uses this status because manifest recovery restores the wallet materialization but not Bullnym registration state.

Once a wallet materialization is returned as `created`, `alreadyPresent`, or `requiresProductReactivation`, it is treated as current local wallet inventory.
If manifest recording then fails, recovery returns `failedManifestRecord` for those wallets and rolls back newly created deterministic wallets best-effort when the materializer supplies a rollback callback.
Rollback is only allowed inside the deterministic wallet materializer or through its explicit rollback callback; keychain recovery never edits manifest files directly.
