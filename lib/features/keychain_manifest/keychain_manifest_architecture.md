# Keychain Manifest Architecture

## Scope

`keychain_manifest` records durable local metadata for app-created BIP85
materializations. It records reserved BIP85 derivations and typed
materializations of those derivations. Wallet materializations are the first
supported materialization type, with BTCPay as the first writer. It never stores
mnemonic words, seeds, private keys, or descriptors.

Manifest entries are durable local inventory, not product/server state. Once a
wallet materialization has been created and recorded, product failures such as
remote rejection, settings/default application failure, or connection-state
persistence failure keep the manifest entry. This PR intentionally treats the
manifest as local retry/recovery metadata and inventory, not product rollback
state. Later retries of the same record operation may idempotently add missing
proven entries, but this PR does not implement a separate repair API or flow.
If a multi-wallet record call partially succeeds and later materializations
fail, the successfully recorded rows remain durable. A later retry must record
missing proven materializations idempotently instead of rolling back valid rows.

It does not create, export, import, publish, fetch, or restore a manifest file.
It records local derivation metadata that may serve as input to a future
snapshot design. This PR does not define a snapshot/export contract, and
non-wallet materialization types are out of scope.

## Boundaries

- `keychain_manifest` owns local keychain manifest entries, typed
  materializations, and persistence.
- `bip85_registry` owns reserved path policy.
- Recording is derivation-proven: callers pass the BIP85 path that was actually
  derived during materialization, and recording refuses the request as an
  invalid entry when that path does not match the reservation's exact path.
- Product features, such as BTCPay, record entries through
  `keychain_manifest/public` only.
- The public boundary records wallet materializations only. Product features do
  not receive inserted-row rollback tokens or a public delete API for
  current-attempt rollback.
- `keychain_manifest` must not import BTCPay, Get Paid, external receive
  wallets, Nostr, or UI features.

## Entry Identity

Keychain entries are generic at the reserved-path identity level and are
identified by:

- parent fingerprint
- registry-relative BIP85 path

Wallet materializations attach wallet-specific metadata to a keychain entry and
are identified by:

- wallet id

The child seed fingerprint is stored on each wallet materialization, because it
is wallet materialization metadata. Non-wallet BIP85 entries must not need a
dummy seed fingerprint.
