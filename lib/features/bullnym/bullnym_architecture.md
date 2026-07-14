# Bullnym

Bullnym owns the shared Bullnym HTTP protocol foundation for authenticated
registration, donation-page, currency, and recipient-invoice calls.

## Scope

This feature owns:

- Bullnym registration, delete, and lookup protocol calls;
- Bullnym registration, donation-page, and invoice signing payload construction;
- permanent-name capability, validation, status, quota, alias intent, and
  structured ownership-conflict values;
- a narrow domain use-case boundary and outbound Bullnym client port;
- a small Dio HTTP client in the data layer that implements the port;
- a sealed `BullnymFailure` family returned through typed `Result` values;
- raw recipient-invoice wire DTOs used by the owning `invoices` feature;
- a public facade for feature callers.

It does not own Lightning Address UI, wallet materialization, wallet manifest
publishing or recovery, NIP-05 registration, relay publishing, invoice
settlement interpretation or polling, payment-page/invoice UI, DMs, local
storage, or autosweep behavior.

## Protocol subset

The current protocol subset reflects the mobile Bullnym client contract. The
mobile adapter accepts optional fields only when the server returns them; product
code must not assume fields beyond this documented subset.

The foundation contract implements these registration and capability fields:

- public `GET /version`, with optional `public_name_policy`;
- `POST /register` with `nym`, `ct_descriptor`, `npub`, `signature`, and
  `timestamp`;
- register response fields `nym`, `lightning_address`, and optional validated
  `quota`;
- `DELETE /register` with `nym`, `npub`, `signature`, and `timestamp`;
- `GET /register/lookup?npub=:hex` with response fields `nym`, `active`, and
  optional `lightning_address`. When `public_name_policy` is exactly
  `permanent_names_v1`, lookup also requires `lightning_address_online`, the
  present-but-nullable `alias`, and internally consistent `quota`;
- Bullpay LA v2 signing layout:
  `bullpay-la-v2\0action\0npub_hex\0nym\0(payload\0)*timestamp`.

This feature intentionally does not send an extra public verification key field or
expose derived Lightning Address behavior beyond returning server-supplied
address fields. `active` remains only the compatibility Lightning Address
online status; names have no active/inactive state.

Capability gating begins with `/version` because lookup for a never-registered
npub is an error envelope without a policy. Missing or unknown policy is a valid
old-server result and leaves permanent-name behavior disabled. Once the exact
policy is advertised, malformed or inconsistent known lookup fields fail closed
as `InvalidServerResponse`; unknown future fields remain tolerated. This
protocol slice publishes the seam but enables no user-facing name UI.

## Donation-page surface

The shared client also carries the donation-page wire surface consumed by the
`payment_page` feature (and, later, the POS surface — the same methods with
`kind = pos`). The `kind` parameter is generic on this client; product features
pin their own value.

- `PUT /donation-page` — signed upsert (`donation-page-save`). Body:
  `nym`, `npub`, `ct_descriptor`, `header`, `description`, `display_currency`,
  `website`, `twitter`, `instagram`, `enabled`, `kind`, `timestamp`,
  `signature`, plus `alias` only for an explicit first claim. Preserve omits
  both the JSON key and signed field. `pos_mode` is never sent.
- `DELETE /donation-page` — signed soft-archive (`donation-page-archive`). Body:
  `nym`, `npub`, `kind`, `timestamp`, `signature`.
- `GET /donation-page/:nym?kind=` — unsigned public read; `DonationPageNotFound`
  when the row is absent. The view never echoes `ct_descriptor`; it carries the
  nullable permanent owner alias and a validated server-returned `public_url`.
- `GET /api/v1/supported-currencies` — unsigned; `{currencies: [{code,
  precision}]}`.

### Optional-trailing signed-field rule

The save signed payload is the seven mandatory fields —
`header, description, display_currency, website, twitter, instagram, enabled` —
with absent optionals signed as empty strings so the NUL-separator count is
stable. This client never sends `pos_mode`, always sends a non-empty
`ct_descriptor`, and always sends `kind`. Preserve therefore remains
byte-for-byte the seven mandatory fields plus `ct_descriptor`, then `kind`.
An explicit non-empty first alias claim appends `alias` after `kind` as the
newest terminal optional field. Archive signs `[kind]` only. Independent oracle
tests pin Page and POS layouts; no domain intent can sign an empty alias or
represent clear, replace, deactivate, or reactivate.

### Public URL trust boundary

The client consumes rather than composes Page and POS share URLs. Before a
`public_url` crosses the Bullnym boundary, it must use the explicitly trusted
public origin, have no userinfo/query/fragment, stay within the length bound,
and match the returned nym/alias and kind route exactly. HTTPS is mandatory
except for the existing localhost/loopback HTTP fixture exception. API and
public origins may differ only through the explicit `BULLNYM_PUBLIC_BASE_URL`
configuration. Invalid server URLs become `InvalidServerResponse`.

Stable coded conflict envelopes are decoded before HTTP status handling, so
legacy HTTP 200 `NymTaken` (normalized to `NameTaken`) and target HTTP 409
conflicts behave consistently. Optional owned-nym/owned-alias details are typed;
server `reason` remains diagnostic-only.

## Signing

Bullnym authenticated writes are signed with the caller-supplied
`BullnymAuthSigner`. The signer exposes only the Bullnym authentication public key
and one-shot hash signing callback; this feature does not derive keys, own wallet
seeds, or retain signing handles.

Signing payload and timestamp construction are internal to the Bullnym domain use
cases. Public callers provide the signer and operation inputs; they do not
construct wire messages or choose protocol timestamps.

## Recipient-invoice wire surface

Bullnym carries the signed create/cancel/list endpoints and unsigned public
status endpoint for recipient invoices. These shapes stay raw at this boundary:
the `invoices` feature maps them into its own domain and owns all settlement
meaning and UI behavior.

The deployed status contract includes nullable `presentation_status` and the
required `bitcoin_direct_observations` list. Each observation preserves
`source`, `rail`, `txid`, `vout`, `address`, `amount_sat`, `confirmations`,
nullable `block_height`, `state`, `first_seen_at_unix`, and
`last_seen_at_unix`. The authenticated list contract additionally carries
nullable `presentation_status` and optional `memo`. Unknown fields are ignored;
known fields fail closed when their wire types are invalid.

## Boundaries

Later features should import `features/bullnym/public/bullnym_facade.dart`, not
the HTTP client, domain port, signing helpers, or wire parser internals directly.

The intended dependency direction is:

`public facade -> domain use cases -> BullnymClientPort -> data HTTP client`.

The data HTTP client owns Dio and JSON decoding. The facade returns only typed
Bullnym values and `Result<T, BullnymFailure>`; foreign library exceptions stop
at the data boundary, while programmer `Error`s remain uncaught.

The Bullnym API and trusted public origins are configurable.
`BullnymHttpClient` accepts explicit `baseUrl` and `publicBaseUrl` values from
DI/callers. Defaults come from the `BULLNYM_BASE_URL` and
`BULLNYM_PUBLIC_BASE_URL` `--dart-define` values with production fallbacks.
Product wiring must not accept or launch an arbitrary server-returned origin.

Server `reason` fields and `Failure.logMessage` are diagnostic-only. UI maps the
sealed variants through `BullnymFailureL10n` and never displays backend text.

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
