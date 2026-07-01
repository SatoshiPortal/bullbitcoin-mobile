# Lightning Address

Lightning Address owns app-side orchestration for registering, deleting, and checking the active Bullnym registration for a wallet identity.

## Scope

This PR owns:

- a public Lightning Address facade;
- domain use cases for register, delete, and lookup/status;
- mapping Bullnym failures into Lightning Address domain errors;
- documentation and feature graph edges.

It does not own NIP-05 registration, payment pages, wallet materialization, wallet manifest publish/recovery, Nostr relay/profile/DM behavior, autosweep, local persistence, routed UI, or l10n.

## Boundaries

Lightning Address consumes only public facades:

- `features/bullnym/public/bullnym_facade.dart`;
- `features/nostr_identity/public/nostr_identity_facade.dart`.

It does not import Bullnym internals, Bullnym signing helpers, Bullnym HTTP adapters, or raw Nostr derivation paths.
Registration and delete derive the Bullnym server-auth public key and signing operation through the role-named Nostr Identity facade methods.

Registration and delete receive `xprvBase58` only as point-of-use method input so Lightning Address can build a one-shot Bullnym auth signer through Nostr Identity.
They pass the confidential descriptor through to Bullnym registration.
Lookup accepts the Bullnym auth public key/npub hex and does not require wallet secret material.
Lightning Address does not create, persist, materialize, or own wallet secrets or descriptors.
A later wallet-owning application flow should avoid storing xprv-bearing request objects in UI, BLoC, or retry state.

Lookup currently reflects the Bullnym public lookup contract: it reports the registered nym and whether it is active.
It does not synthesize a copyable Lightning Address from a hardcoded domain.
Canonical display/copy address after lookup belongs in a later backend/facade contract or wallet/config-owned flow.

The only local nym validation owned here is rejecting empty or whitespace-only values before key derivation and network calls.
Character sets, case policy, length limits, reserved names, and normalization remain Bullnym protocol or product decisions.
