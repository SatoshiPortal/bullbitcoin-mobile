# Lightning Address

Lightning Address owns app-side orchestration for registering, deleting, and
checking the active Bullnym registration for a wallet identity.

## Scope

This PR owns:

- a public Lightning Address facade;
- application use cases for register, delete, and lookup/status;
- mapping Bullnym failures into Lightning Address application errors;
- documentation and feature graph edges.

It does not own NIP-05 registration, payment pages, wallet materialization,
wallet manifest publish/recovery, Nostr relay/profile/DM behavior, autosweep,
local persistence, routed UI, or l10n.

## Boundaries

Lightning Address consumes only public facades:

- `features/bullnym/public/bullnym_facade.dart`;
- `features/nostr_identity/public/nostr_identity_facade.dart`.

It does not import Bullnym internals, Bullnym signing helpers, Bullnym HTTP
adapters, or raw Nostr derivation paths. The Bullnym server-auth handle is
derived through the role-named Nostr Identity facade method.

The confidential descriptor is caller-supplied in this foundation PR. Wallet
materialization and descriptor ownership belong to a later wallet-owning flow.
