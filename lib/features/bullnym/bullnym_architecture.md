# Bullnym

Bullnym owns the shared Bullnym HTTP protocol foundation for authenticated
Bullnym registration, deletion, and lookup calls.

## Scope

This PR owns:

- Bullnym registration, delete, and lookup protocol calls;
- Bullnym registration/delete signing payload construction;
- a narrow domain use-case boundary and outbound Bullnym client port;
- a small Dio HTTP client in the data layer that implements the port;
- a public facade for later feature callers.

It does not own Lightning Address UI, wallet materialization, wallet manifest
publishing or recovery, NIP-05 registration, relay publishing, invoices, payment
pages, DMs, local storage, or autosweep behavior.

## PR9 Protocol Subset

The current protocol subset reflects the mobile Bullnym client contract. The
mobile adapter accepts optional fields only when the server returns them; product
code must not assume fields beyond this documented subset.

The foundation contract implements only these fields:

- `POST /register` with `nym`, `ct_descriptor`, `npub`, `signature`, and
  `timestamp`;
- register response fields `nym` and `lightning_address`;
- `DELETE /register` with `nym`, `npub`, `signature`, and `timestamp`;
- `GET /register/lookup?npub=:hex` with response fields `nym`, `active`, and
  optional `lightning_address`;
- Bullpay LA v2 signing layout:
  `bullpay-la-v2\0action\0npub_hex\0nym\0(payload\0)*timestamp`.

This feature intentionally does not send an extra public verification key field or
expose derived Lightning Address behavior beyond returning server-supplied
address fields. Server quota/history fields are not part of this minimal public
facade yet; they need an owning follow-up before product UI consumes Bullnym.

## Signing

Bullnym authenticated writes are signed with the caller-supplied
`BullnymAuthSigner`. The signer exposes only the Bullnym authentication public key
and one-shot hash signing callback; this feature does not derive keys, own wallet
seeds, or retain signing handles.

Signing payload and timestamp construction are internal to the Bullnym domain use
cases. Public callers provide the signer and operation inputs; they do not
construct wire messages or choose protocol timestamps.

## Boundaries

Later features should import `features/bullnym/public/bullnym_facade.dart`, not
the HTTP client, domain port, signing helpers, or wire parser internals directly.

The intended dependency direction is:

`public facade -> domain use cases -> BullnymClientPort -> data HTTP client`.

The data HTTP client owns Dio and JSON decoding. Domain models are stable Bullnym
operation results, not backend DTOs, and contain no JSON parsing.

The Bullnym server URL is configurable. `BullnymHttpClient` accepts an explicit
`baseUrl` from DI/callers, and its default comes from the `BULLNYM_BASE_URL`
`--dart-define` with a production fallback. Product wiring must not hardcode a
single Bullnym server URL outside this data boundary.

Server `reason` fields are diagnostic-only. Future UI must map stable Bullnym
error categories to localized user-facing copy instead of displaying backend
text directly.
## Wallet Backup Blobs

Bullnym exposes one authenticated opaque-object contract for the independent
`keychain_manifest` and `wallet_metadata` streams. Public keys are carried in
signed request bodies rather than URLs. The client signs the SHA-256 digest of
the fixed NUL-separated `bullbitcoin-wallet-backup-v1` message and never gives
Bullnym an xprv.

The facade exposes fetch, conditional store, and conditional delete. Dio,
base64 JSON, status mapping, hash verification, and endpoint paths remain in
the data client. A decoded ciphertext is bounded to 2 MiB. Bullnym can observe
source IP, timing, stream pseudonym, and object size, but authenticated
encryption hides wallet metadata.
