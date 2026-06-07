# Bullnym

Bullnym owns the shared Bullnym HTTP protocol foundation for authenticated
Bullnym registration, deletion, and lookup calls.

## Scope

This PR owns:

- Bullnym registration, delete, and lookup protocol calls;
- Bullnym registration/delete signing payload construction;
- a narrow application boundary and outbound Bullnym client port;
- a small HTTP client adapter that implements the port;
- a public facade for later feature callers.

It does not own Lightning Address UI, wallet materialization, wallet manifest
publishing or recovery, NIP-05 registration, relay publishing, invoices, payment
pages, DMs, local storage, or autosweep behavior.

## Verified Protocol Contract

The current wire contract is grounded in the local Bullnym harness:

- `bullnym-tests/src/client/registration.rs`
- `bullnym-tests/src/wallet/la_v2.rs`

PR9 implements only the fields evidenced there:

- `POST /register` with `nym`, `ct_descriptor`, `npub`, `signature`, and
  `timestamp`;
- register response fields `nym` and `lightning_address`;
- `DELETE /register` with `nym`, `npub`, `signature`, and `timestamp`;
- `GET /register/lookup?npub=:hex` with response fields `nym` and `active`;
- Bullpay LA v2 signing layout:
  `bullpay-la-v2\0action\0npub_hex\0nym\0(payload\0)*timestamp`.

This PR intentionally does not send an extra public verification key field,
parse quota/history fields, or expose derived Lightning Address behavior beyond
returning the server's register response field.

## Signing

Bullnym authenticated writes are signed with the caller-supplied Bullnym server
authentication Nostr handle. The handle is expected to come from
`features/nostr_identity` role `9000'/2'/1'`; this feature does not derive keys
or choose wallet seeds.

Signing and timestamp construction are internal to the Bullnym application
use cases. Public callers provide the authenticated handle and operation inputs;
they do not construct wire messages or choose protocol timestamps.

## Boundaries

`features/bullnym` may depend on `core/nostr` and expose a public facade. Later
features should import `features/bullnym/public/bullnym_facade.dart`, not the
HTTP client, application port, signing helpers, or wire parser internals
directly.

The intended dependency direction is:

`public facade -> application use cases -> BullnymClientPort -> HTTP adapter`.

The HTTP adapter owns Dio and JSON decoding. Domain models are stable Bullnym
operation results, not backend DTOs, and contain no JSON parsing.

Server `reason` and `details` fields are diagnostic-only. Future UI must map
stable Bullnym error categories to localized user-facing copy instead of
displaying backend text directly.
