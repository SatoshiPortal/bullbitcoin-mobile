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

It can build an on-demand manifest file payload from local records for a
requested parent fingerprint. The local Drift records remain the source of
truth; the file payload is a read-only projection and is not cached as product
state. This PR does not import, publish, fetch, or restore a manifest file, and
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
- The public boundary may build a manifest file payload, but file operations
  must not mutate local manifest inventory.
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

Wallet materializations store no wallet-purpose value. The network family is
derivable from the stored `network`, and feature ownership already lives on the
entry's `ownerFeature`, so a purpose column would duplicate both and freeze a
redundant string into the persisted schema and the manifest file contract.

## Manifest File

The manifest file is a serialized projection generated from local
`keychain_manifest` records. It is not the current-device source of truth, is
not maintained as a separate local file, and does not become a recovery artifact
until a later restore flow defines those semantics.

Current-device source of truth:

- `bip85_registry` defines reserved paths and purposes.
- `keychain_manifest` database records define which app-created BIP85 material
  has been recorded for recovery/retry inventory.
- The manifest file payload is the latest projection of those records at the
  moment a caller builds it.
- The payload does not prove that every recorded wallet still exists locally.
  A future consumer that needs current wallet-existence guarantees must join
  against wallet inventory and define missing-wallet behavior explicitly.

The v1 file is deterministic JSON with this shape:

```json
{
  "version": 1,
  "parentFingerprint": "fedcba98",
  "generatedAt": 20,
  "inventoryUpdatedAt": 12,
  "entries": [
    {
      "entryId": "fedcba98:39'/0'/12'/100'",
      "bip85DerivationPath": "39'/0'/12'/100'",
      "reservationId": "btcpay_wallet_seed",
      "entryType": "walletSeed",
      "ownerFeature": "btcpay",
      "bip85Application": 39,
      "bip85Index": 100,
      "createdAt": 10,
      "updatedAt": 12,
      "materializations": [
        {
          "type": "wallet",
          "walletId": "btc-wallet",
          "childSeedFingerprint": "0123abcd",
          "network": "bitcoinMainnet",
          "scriptType": "bip84",
          "createdAt": 10,
          "updatedAt": 10
        }
      ]
    }
  ]
}
```

Rules:

- `version` must be `1`.
- Fingerprints must be normalized 8-character lowercase hex values.
- `bip85DerivationPath` is the registry-relative hardened path.
- `entryId` is derived from parent fingerprint and BIP85 path.
- Entry ids must be unique across entries, and wallet ids must be unique
  across all materializations in the file, mirroring local record uniqueness.
- `inventoryUpdatedAt` is the data-recency timestamp: the latest `updatedAt`
  among included entries and materializations. An empty manifest serializes
  `inventoryUpdatedAt` as `0`.
- Cross-manifest recency ordering uses data recency (`inventoryUpdatedAt`),
  so an empty manifest never outranks a populated one. `generatedAt` records
  when the payload was built and is informational only; it must not be used
  to rank manifests.
- V1 supports only wallet materializations with `"type": "wallet"`.
- Public callers must explicitly opt in before exporting an empty manifest.
- This PR only encodes the v1 payload. Decoding, import validation, and restore
  semantics belong to a later consumer PR.

The payload is generated on demand by callers that need a serialized projection.
Transport, import, restore, and UI flows are out of scope and are not specified
by this PR.
