# BIP85 Registry Architecture

The BIP85 registry owns static reservations for derivation paths reserved by
first-party features. It is policy, not runtime state: it does not record
created secrets, wallets, recovery-manifest entries, or allocation history.

## Boundaries

- `domain/` defines immutable reservation metadata and the static entries.
- `public/` exposes read-only lookup and exclusion helpers.
- The composition root may register the stateless facade for consumers.
- The registry owns no database, repository, datasource, UI, allocator, or
  runtime manifest writer.
- Reservation metadata includes the canonical deterministic alias used when
  deriving or reusing the reserved BIP85 child. Product features and recovery
  use that alias through the registry instead of duplicating product constants.

## Reservation Shapes

Reservations come in exactly two typed shapes, enforced at construction:

- Wallet-seed reservations (`Bip85WalletSeedReservation`) materialize a BIP85
  child wallet seed. Their scope requires a hardened `index` segment and
  exposes it as a typed `walletIndex`; construction throws if the segment is
  missing.
- Key reservations (`Bip85KeyReservation`) reserve non-wallet key material.
  Their scope has no wallet index and construction throws if an `index`
  segment is supplied, so a key reservation cannot even be asked for a wallet
  index.

Both shapes derive their exact path from the application number and the ordered
path segments; the path string is never stored separately.

## Current Reservations

BTCPay reserves BIP85 path `39'/0'/12'/100'`: a BIP39 English 12-word child
mnemonic at child index `100`. The registry is the source of truth for this
path. The interim development index `77` was never released and has no
migration or compatibility behavior.

Lightning Address reserves BIP85 path `39'/0'/12'/101'`, which is a BIP39
English 12-word child mnemonic at child index `101`.

Payment Page reserves BIP85 path `39'/0'/12'/102'`, which is a BIP39 English
12-word child mnemonic at child index `102`.

Nostr role keys reserve the app-owned Nostr namespace paths:

- `9000'/1'/1'` for the encrypted keychain-backup stream identity.
- `9000'/2'/1'` for Bullnym server authentication.
- `9000'/3'/1'` for future NIP-05 public nym verification.
- `9000'/4'/1'` for wallet metadata backup publishing and recovery.

These Nostr-compatible reservations are static namespace policy only. They do
not require Nostr events or relays. The keychain role signs Bullnym backup
requests; the other roles retain their existing product responsibilities.
The exact app number and role segments are the locked namespace allocation;
later Nostr behavior work may consume these ids and paths, but should not infer
runtime semantics from this registry entry alone.

The remote-backup encryption keys use separate reservations in Bull's custom BIP85 application namespace:

- Keychain Manifest reserves `1642'/0'/1'` for remote keychain-manifest snapshot payloads.
- Wallet Metadata Backup reserves `1642'/0'/2'` for remote wallet-metadata snapshot payloads, including BIP329 labels and future metadata sections.

These encryption reservations must not be reused for each other, RecoverBull vault backups, Nostr signing, Bullnym authentication, or wallet-seed materialization. Keeping the keychain-manifest and wallet-metadata keys distinct prevents either backup stream from providing a cryptographic correlation handle for the other and allows the two backup features to be activated independently.
The consuming features own encryption and encrypted-payload semantics; the registry only blocks and names the paths.

Future reservations should add typed entries here only when a first-party
feature needs a stable, blocked path. User-created ad hoc BIP85 outputs remain
outside this registry unless they become a first-party reserved namespace.

## Reservations Outside This Registry

Ark and RecoverBull hold BIP85 reservations outside this registry (Ark at hex
application index `11811`; RecoverBull at application `1608'`). Before any
manual or custom allocation feature is built on top of this registry, a
collision audit against those external reservations is required.
