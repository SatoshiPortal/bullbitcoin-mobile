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

The `xprvBase58` and confidential descriptor command fields are caller-supplied
foundation inputs in this PR. Lightning Address uses the xprv only to ask Nostr
Identity for the Bullnym server-auth handle, and passes the descriptor through
to Bullnym registration. It does not create, persist, materialize, or own wallet
secrets or descriptors. A later wallet-owning application flow should wrap or
replace this command construction before any routed UI passes wallet material.

Lookup currently reflects the Bullnym public lookup contract: it reports the
registered nym and whether it is active. It does not synthesize a copyable
Lightning Address from a hardcoded domain. Canonical display/copy address after
lookup belongs in a later backend/facade contract or wallet/config-owned flow.

The only local nym validation owned here is rejecting empty or whitespace-only
values before key derivation and network calls. Character sets, case policy,
length limits, reserved names, and normalization remain Bullnym protocol or
product decisions.
