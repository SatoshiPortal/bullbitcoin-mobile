# Core Nostr

`core/nostr` is the app-wide generic Nostr key boundary. It owns BIP85 path
derivation, BIP340 hash signing, and public-key access through the existing
`bitcoin_base` crypto stack.

Feature-specific protocol semantics stay outside this package. Bullnym actions,
Lightning Address message fields, wallet manifest events, profile content,
NIP-05 registration, DMs, and UI policy belong to feature layers.

## BIP85 Derivation

Nostr keys are derived with BIP85 application `9000`:

```text
m/83696968'/9000'/{identity}'/{account_index}'
```

Generic callers pass a BIP85 hardened path accepted by `Bip85HardenedPath`.
Bull product features should use the role-named helpers exposed by
`features/nostr_identity/public/nostr_identity_facade.dart`, which consumes the
canonical registry suffix paths, such as `9000'/1'/1'`, from
`features/bip85_registry`.

## Public Surface

- `NostrKeychainHandle` wraps the key object without exposing raw
  secret-key material.
- `NostrKeychainHandle` derives keys from BIP85 hardened paths, returns
  x-only public keys, and signs explicit 32-byte hash hex values.

## Boundaries

- DTOs and persistence models must not contain `NostrKeychainHandle`.
- Feature layers pass public keys and signatures across their own ports.
- Feature layers own their protocol-specific event contents and relay behavior.
- `toString()` implementations must never include secret-key material.
