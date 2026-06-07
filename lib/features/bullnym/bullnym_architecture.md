# Bullnym

Bullnym owns the shared Bullnym HTTP protocol foundation used by later Lightning
Address and Get Paid features.

## Scope

This PR owns:

- Bullnym registration, delete, and lookup wire DTOs;
- Bullnym registration/delete signing payload construction;
- a small HTTP client adapter;
- a public facade for later feature callers.

It does not own Lightning Address UI, wallet materialization, wallet manifest
publishing or recovery, NIP-05 registration, relay publishing, invoices, payment
pages, DMs, local storage, or autosweep behavior.

## Signing

Bullnym authenticated writes are signed with the caller-supplied Bullnym server
authentication Nostr handle. The handle is expected to come from
`features/nostr_identity` role `9000'/2'/1'`; this feature does not derive keys
or choose wallet seeds.

Registration also carries the public nym verification key supplied by the
caller. That keeps Bullnym auth and public nym verification as separate Nostr
roles without implementing NIP-05 registration here.

## Boundaries

`features/bullnym` may depend on `core/nostr` and expose a public facade. Later
features should import `features/bullnym/public/bullnym_facade.dart`, not the
HTTP client or DTO internals directly.
