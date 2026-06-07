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
state. It can also validate an imported v1 payload into typed import intents for
later consumer flows. Import parsing does not persist, delete, create wallets,
publish, fetch, or restore product state, and non-wallet materialization types
are out of scope for v1.

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
  wallets, keychain recovery, Nostr, or UI features.

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

The v1 file is deterministic JSON. Shown pretty-printed for readability; the
serialized payload contains no whitespace (see canonical form below):

```json
{
  "version": 1,
  "parentFingerprint": "fedcba98",
  "generatedAt": 1751328000,
  "inventoryUpdatedAt": 1751241600,
  "entryCount": 1,
  "materializationCount": 1,
  "entries": [
    {
      "entryId": "fedcba98:39'/0'/12'/100'",
      "bip85DerivationPath": "39'/0'/12'/100'",
      "reservationId": "btcpay_wallet_seed",
      "entryType": "walletSeed",
      "ownerFeature": "btcpay",
      "bip85Application": 39,
      "bip85Index": 100,
      "createdAt": 1751241600,
      "updatedAt": 1751241600,
      "materializations": [
        {
          "type": "wallet",
          "walletId": "wpkh([0123abcd/84h/0h/0h])",
          "childSeedFingerprint": "0123abcd",
          "network": "bitcoinMainnet",
          "scriptType": "bip84",
          "createdAt": 1751241600,
          "updatedAt": 1751241600
        }
      ]
    }
  ]
}
```

`walletId` is the wallet's descriptor-origin string, e.g.
`wpkh([0123abcd/84h/0h/0h])` for a BIP84 Bitcoin mainnet wallet whose child
seed fingerprint is `0123abcd`. It is deterministic from the child seed
fingerprint, script type, and network.

### Canonical form

Every v1 payload has exactly one byte representation:

- All timestamps (`generatedAt`, `inventoryUpdatedAt`, `createdAt`,
  `updatedAt`) are Unix timestamps in seconds, UTC.
- JSON object keys appear in the fixed order shown in the example above:
  - top level: `version`, `parentFingerprint`, `generatedAt`,
    `inventoryUpdatedAt`, `entryCount`, `materializationCount`, `entries`;
  - entry: `entryId`, `bip85DerivationPath`, `reservationId`, `entryType`,
    `ownerFeature`, `bip85Application`, `bip85Index`, `createdAt`,
    `updatedAt`, `materializations`;
  - materialization: `type`, `walletId`, `childSeedFingerprint`, `network`,
    `scriptType`, `createdAt`, `updatedAt`.
- Entries are sorted by `bip85DerivationPath`, then by `entryId`.
- Materializations within an entry are sorted by `network`, then by
  `walletId`.
- The payload contains no whitespace: no spaces after separators, no
  newlines, no indentation.
- Unknown fields are ignored on read. This is a deliberate forward-compat
  decision: a v1 reader accepts payloads that carry additional fields from a
  newer writer, and it validates only the fields specified here. Writers must
  not emit fields outside this specification.

Rules:

- `version` must be `1`.
- Fingerprints must be normalized 8-character lowercase hex values.
- `bip85DerivationPath` is the registry-relative hardened path.
- `entryId` is derived from parent fingerprint and BIP85 path.
- Entry ids must be unique across entries, and wallet ids must be unique
  across all materializations in the file, mirroring local record uniqueness.
- `entryCount` and `materializationCount` are integrity counts validated on
  build: `entryCount` must equal the number of entries, and
  `materializationCount` must equal the total number of materializations
  across all entries.
- `inventoryUpdatedAt` is the data-recency timestamp: the latest `updatedAt`
  among included entries and materializations. An empty manifest serializes
  `inventoryUpdatedAt` as `0`. V1 decode rejects payloads whose declared
  `inventoryUpdatedAt` does not match the value derived from the entries.
- Cross-manifest recency ordering uses data recency (`inventoryUpdatedAt`),
  so an empty manifest never outranks a populated one. `generatedAt` records
  when the payload was built and is informational only; it must not be used
  to rank manifests.
- V1 supports only wallet materializations with `"type": "wallet"`.
- Enumerated fields carry frozen wire vocabulary (see the table below).
- Public callers must explicitly opt in before exporting an empty manifest.
- V1 decode validates the payload wire shape in `data/`, then validates registry
  metadata into import intents in `domain/usecases`. Public import parsing
  requires the caller's expected parent fingerprint and rejects files from a
  different wallet before returning a plan. Wallet creation and restore semantics
  belong to `keychain_recovery`.
- Import parsing refuses an empty plan unless the caller explicitly opts in,
  mirroring the empty-export gate: silently returning a plan with nothing to
  recover would be indistinguishable from a successful import.

### Consumer obligations

An imported manifest file is unsigned, unauthenticated input. Parsing validates
shape, internal consistency, and registry metadata; it cannot prove that the
file's claims are true for this device. Consumers of an import plan MUST:

- Source `expectedParentFingerprint` from local seed storage. It must never be
  taken from the file, from user input, or from another remote artifact.
- Treat `childSeedFingerprint` on wallet materialization intents as
  file-CLAIMED. After deriving the child seed, the consumer MUST verify the
  derived fingerprint against the claimed one and refuse the materialization on
  mismatch.
- Treat `walletId` as file-CLAIMED. The consumer MUST recompute the wallet id
  from the descriptor derived locally (child seed fingerprint, script type,
  network) and never trust or persist the claimed value.
- Treat every string field on intents as untrusted input when rendering UI:
  no markup interpretation, apply length truncation where layout requires it.
- Require explicit user confirmation for empty plans (parsed with
  `allowEmpty: true`); an empty plan restores nothing.
- Handle environment/network mismatches (for example a testnet materialization
  on a mainnet build): filtering or refusing such intents is the consumer's
  responsibility, not the parser's.

### Frozen wire vocabulary

The enumerated v1 fields below serialize the `.name` of a production enum (or
a serialization constant). These strings are frozen wire vocabulary: renaming
a source enum must not change what is serialized, and a contract test pins
every value. Adding or changing a value is a versioned wire-format decision,
not a refactor.

| Field | Allowed values | Source |
| --- | --- | --- |
| `type` (materialization) | `wallet` | `KeychainManifestFileWalletMaterialization.type` constant |
| `entryType` | `walletSeed` | `Bip85ReservationPurpose` (`bip85_registry`) |
| `ownerFeature` | `btcpay` | `Bip85ReservationOwner` (`bip85_registry`) |
| `reservationId` | `btcpay_wallet_seed` | `bip85_registry` reservation ids |
| `network` | `bitcoinMainnet`, `bitcoinTestnet`, `liquidMainnet`, `liquidTestnet` | `Network` (`core/wallet`) |
| `scriptType` | `bip84`, `bip49`, `bip44` | `ScriptType` (`core/wallet`) |

The payload is generated on demand by callers that need a serialized projection.
Transport, wallet creation, product restore, and UI flows are out of scope and
are not specified by this feature.
