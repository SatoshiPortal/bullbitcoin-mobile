# Lightning Address

Lightning Address owns app-side orchestration for registering, deleting, and checking the active Bullnym registration for a wallet identity.

## Scope

This PR owns:

- a public Lightning Address facade;
- domain use cases for prepare wallet, register, delete, and lookup/status;
- deterministic Liquid receive wallet materialization through the Deterministic Wallets facade;
- keychain manifest metadata recording through the Keychain Manifest facade;
- mapping Bullnym failures into Lightning Address domain errors;
- localized Lightning Address domain error copy, documentation, and feature graph edges.

It does not own NIP-05 registration, payment pages, wallet manifest publish/recovery, Nostr relay/profile/DM behavior, autosweep, local persistence, or routed UI.

## Boundaries

Lightning Address consumes only public facades:

- `features/bullnym/public/bullnym_facade.dart`;
- `features/deterministic_wallets/public/deterministic_wallets_facade.dart`;
- `features/keychain_manifest/public/keychain_manifest_facade.dart`;
- `features/nostr_identity/public/nostr_identity_facade.dart`.

It does not import Bullnym internals, Bullnym signing helpers, Bullnym HTTP adapters, or raw Nostr derivation paths.
Registration and delete derive the Bullnym server-auth public key and signing operation through the role-named Nostr Identity facade methods.

Registration and delete receive `xprvBase58` only as point-of-use method input so Lightning Address can build a one-shot Bullnym auth signer through Nostr Identity.
They pass the confidential descriptor through to Bullnym registration.
Lookup accepts the Bullnym auth public key/npub hex and does not require wallet secret material.
Lightning Address does not persist or own wallet secrets.
It delegates local wallet creation/reuse to Deterministic Wallets, records recovery metadata through Keychain Manifest, and only handles returned public descriptors for Bullnym registration.
A later wallet-owning application flow should avoid storing xprv-bearing request objects in UI, BLoC, or retry state.

`prepareWallet()` creates or reuses the dedicated Liquid receive wallet from the `lightning_address_wallet_seed` BIP85 reservation and records the resulting wallet materialization in the keychain manifest.
If manifest recording fails after local wallet creation, the use case rolls back newly created deterministic wallets best-effort and returns a local preparation error.
This applies the canonical rollback-timing rule in `ARCHITECTURE.md` (Error handling): the durable manifest record is the commitment point — a failure before it is fatal/retryable and rolls the local wallet back, a failure after it is best-effort (logged, never un-done).
Recovered Lightning Address wallets require product reactivation because the manifest can restore wallet materialization metadata but cannot prove an active Bullnym server registration.

Lookup currently reflects the Bullnym public lookup contract: it reports the registered nym and whether it is active.
It does not synthesize a copyable Lightning Address from a hardcoded domain.
Canonical display/copy address after lookup belongs in a later backend/facade contract or wallet/config-owned flow.

The only local nym validation owned here is rejecting empty or whitespace-only values before key derivation and network calls.
Character sets, case policy, length limits, reserved names, and normalization remain Bullnym protocol or product decisions.
