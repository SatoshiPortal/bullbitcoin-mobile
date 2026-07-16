# Nostr-Compatible Identity

Nostr Identity owns Bull's role-named access to BIP85-derived x-only/BIP340 keys. Some roles are used by Nostr features; the wallet-manifest and wallet-metadata roles authenticate opaque Bullnym backup requests and never construct or publish Nostr events.

## Scope

This feature owns:

- role-named xprv-based derivation helpers;
- validation that identity derivation consumes role-appropriate reservations owned by `features/bip85_registry`.

It does not own Nostr relay publishing, Bullnym wire messages, backup payloads, profile event content, UI, storage, rotation, DMs, or user-created Nostr accounts.

## Derivation

Nostr keys use the BIP85 Nostr application path:

```text
m/83696968'/9000'/{identity}'/{account_index}'
```

Reserved roles:

- `1'/1'` => wallet-manifest Bullnym authentication;
- `2'/1'` => Bullnym server authentication;
- `3'/1'` => Bullnym NIP-05 public nym verification;
- `4'/1'` => wallet-metadata Bullnym authentication.

Product features must use role-named helpers and must not pass raw identity/account integers at call sites.

## Boundaries

`core/nostr` remains generic: path derivation, BIP340 hash signing, and public-key access. Product role semantics live here, not in `core/nostr` or individual product features. The concrete reservation paths stay in `features/bip85_registry`; this feature consumes the wallet-manifest, wallet-metadata, Bullnym-auth, and Bullnym NIP-05 verification reservations through its public facade.

The wallet-manifest, wallet-metadata, and Bullnym-authentication roles expose public-key derivation and hash signing without exposing private key material. The NIP-05 verification role exposes only its public key so registration cannot accidentally use the public identity as an authentication signer.

The wallet-manifest and wallet-metadata roles deliberately use different identities. Consumers must not substitute one role for the other because Bullnym stores them as independently activated and unlinkable stream keys.
