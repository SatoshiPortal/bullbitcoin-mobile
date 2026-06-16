# Keychain Manifest Architecture

## Scope

`keychain_manifest` records durable local metadata for app-created BIP85 key
material. It records reserved BIP85 derivations and typed materializations of
those derivations. Wallet materializations are the first supported
materialization type, with BTCPay as the first writer.

Manifest entries are durable local inventory, not product/server state. Once a
wallet materialization has been created and recorded, product failures such as
remote rejection, settings/default application failure, or connection-state
persistence failure must not delete the manifest entry. Later retries of the
same record operation may idempotently add missing proven entries, but this PR
does not implement a separate repair API or flow.
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

The child seed fingerprint is stored on each wallet materialization, because it is
wallet-key materialization metadata. Non-wallet BIP85 entries must not need a
dummy seed fingerprint.
