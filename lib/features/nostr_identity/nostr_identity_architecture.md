# Nostr Identity

Nostr Identity owns Bull's role-named access to reserved BIP85 Nostr keys. It is
a planned shared boundary for Get Paid, Lightning Address, wallet manifest
recovery, and future Nostr-backed product features.

## Scope

This feature owns:

- role-named xprv-based derivation helpers;
- validation that Nostr identity derivation consumes reservations owned by
  `features/bip85_registry`.

It does not own Nostr relay publishing, Bullnym wire messages, wallet manifest
events, profile event content, UI, storage, rotation, DMs, or user-created Nostr
accounts.

## Derivation

Nostr keys use the BIP85 Nostr application path:

```text
m/83696968'/9000'/{identity}'/{account_index}'
```

Reserved roles:

- `1'/1'` => wallet manifest publishing and recovery;
- `2'/1'` => Bullnym server authentication;
- `3'/1'` => Bullnym NIP-05 public nym verification.

Product features must use role-named helpers and must not pass raw
identity/account integers at call sites.

## Boundaries

`core/nostr` remains generic: path derivation, hash signing, and public-key
access. Product role semantics live here, not in `core/nostr` and not inside
later receive/Bullnym product features. The concrete reservation paths stay in
`features/bip85_registry`; this feature consumes the current wallet-manifest,
Bullnym-auth, and Bullnym NIP-05 verification reservations through its public
facade.

The Bullnym authentication role alone exposes signing. The NIP-05 verification
role exposes only its public key so registration cannot accidentally use the
public identity as an authentication signer.
