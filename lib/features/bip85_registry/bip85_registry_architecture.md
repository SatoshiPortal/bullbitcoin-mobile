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

## Current Reservation

BTCPay reserves BIP85 path `39'/0'/12'/100'`: a BIP39 English 12-word child
mnemonic at child index `100`. The registry is the source of truth for this
path. The interim development index `77` was never released and has no
migration or compatibility behavior.

Future first-party reservations belong here only after a collision audit.
User-created BIP85 outputs remain outside the registry.

Ark and RecoverBull currently keep their existing reservations outside this
registry (Ark at hex application index `11811`; RecoverBull at application
`1608'`). Any future generic allocator must audit those namespaces first.
