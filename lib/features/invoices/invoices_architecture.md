# Invoices (`features/invoices`)

Lets a merchant create a **wallet-origin Bullpay invoice** from the mobile app
(an amount, a description, an invoice number, a recipient name, an expiry, and a
set of accepted rails), share its public payment URL, then track it to payment
(list / detail / status polling) and cancel it while unpaid. An invoice is a
**one-shot artifact**: created by the key-holder, paid once by one customer,
tracked to a terminal state.

This feature has its OWN hexagon, entry tile, screens, and routes. It REUSES the
shared `bullnym` client (adding four signed `invoice-*` actions) and adds one
core-wallet primitive (a Liquid receive address WITH its blinding secret). It
edits neither `features/payment_page` nor `features/pos`.

## The 2-path contract (DG-I1: UNLINKED-ONLY in v1)

The server exposes signed wallet-origin create in two variants, both BIP-340
Schnorr-signed over `bullpay-la-v2` with the merchant's Get Paid npub:

- **Unlinked (v1):** `POST /api/v1/invoices`, `nym_or_empty = ""`, public render
  at `/invoice/:id`. Needs ONLY the npub identity — no nym / Lightning-Address
  registration.
- **Linked (deferred):** `POST /api/v1/:nym/invoices`, `nym_or_empty = nym`,
  render `/:nym/i/:id`. Requires the signer own that nym.

v1 creates **unlinked** invoices only: the create command's `linkToPageNym`
stays `null` and the app never sends a nym. The facade/port keep `nym` nullable
so linked is a clean additive follow-up (flip `linkToPageNym`) without a wire
change. (`invoice-list` always signs `nym_or_empty = ""`; the list is
npub-wide.)

## Payout-wallet model (DG-I2, money-critical)

The server takes a CLIENT-SUPPLIED payout address and performs NO derivation.
There is **no invoice BIP85 reservation** — invoices register no descriptor,
they hand the server one fresh address per rail per invoice. So the payout
wallet is the user's **DEFAULT spending wallet**:

- LN or Liquid accepted → one fresh confidential Liquid receive address (+ its
  per-address blinding secret) from the DEFAULT Liquid wallet;
- BTC accepted → one fresh Bitcoin receive address from the DEFAULT Bitcoin
  wallet.

Addresses come ONLY from `WalletAddressRepository` on `onlyDefaults` wallets.
No invoice code reads or derives from a reserved Get Paid descriptor
(100/101/102/103), so **no LUD-22 cursor is ever touched** — this satisfies
ISS-F-06's "no interference with LUD-22 cursors" BY CONSTRUCTION. There is no
hidden/autosweep posture (none is needed: an invoice discloses a single
per-invoice address, never a descriptor), **no keychain-manifest classification,
and no recovery heal** — a major simplification versus page/POS.

The `liquid_blinding_key_hex` sent to the server is the **per-address blinding
secret** (what its watcher needs to unblind and detect payment to that specific
output), NEVER the wallet master blinding key or the confidential address's
public blinding key. LWK derives and returns the address/secret pair atomically;
the app does not implement SLIP77 derivation in Dart.

## Signed byte layout (KR-3-analog, DG-I3)

Four `bullpay-la-v2` actions, signed over
`bullpay-la-v2\0<action>\0<npub_hex>\0<nym_or_empty>\0(<field>\0)*<timestamp>`
(server `src/auth.rs::build_la_v2_message`):

- **`invoice-create`** — 13 fields, FIXED order, EVERY field emitted (absent
  optionals as the EMPTY STRING, never skipped): `amount_sat`,
  `fiat_amount_minor`, `fiat_currency`, `public_description`, `recipient_name`,
  `invoice_number`, `accept_btc`, `accept_ln`, `accept_liquid`,
  `bitcoin_address`, `liquid_address`, `liquid_blinding_key_hex`,
  `expires_at_unix`. Booleans serialize as `"true"`/`"false"`.
- **`invoice-cancel`** — 1 field: `[invoice_id]`.
- **`invoice-list`** — 3 fields: `[page, page_size, status_or_empty]`,
  `nym_or_empty` ALWAYS `""`.
- **`invoice-recovery-list`** — zero payload fields and `nym_or_empty` ALWAYS
  `""`. This is a GET-only, npub-wide automatic-fallback projection; it cannot
  choose a destination, trigger a broadcast, or retry execution.

Golden byte-layout vectors are pinned as hand-derived literals (append-only) in
`test/features/bullnym/bullnym_invoice_contract_test.dart`.

## Distinct create / list / status shapes (§3.11)

Create returns only `{invoice_id, share_url}`; the status endpoint returns the
public `InvoiceStatusSnapshot`; the list returns `Invoice[]`. The domain keeps
`Invoice` (list/create) separate from `InvoiceStatusSnapshot` (status); callers
merge them explicitly, never conflate. Public status
(`GET /api/v1/invoices/:id/status`) is **UNSIGNED** — polled by id, no signer.

Automatic fallback supervision is deliberately separate and authenticated:
`GET /api/v1/invoices/recoverable` is signed by the wallet identity and returns
one read-only row per swap, attributed to its original invoice. Current server
states map conservatively: `refund_due` is delayed, `refunding` is in progress,
and `refunded` is confirming because a transaction id alone does not prove
finality. Approved confirmed/finalized/settled and integrity-hold values have
explicit product states; every unknown value stays in progress with no action.
Servers returning 404/405 produce an empty fail-closed projection. Other read
failures never hide the ordinary invoice list or a previously loaded detail.

## Local-only private memo (§3.14)

`privateMemo` is stored as local address labels
(`LabelsFacade.store(NewLabel.addr(..., origin:'invoice:<id>'))`), best-effort
AFTER server success. It NEVER reaches bullnym and NEVER fails a created invoice.

## No local invoice store (§3.15)

Source of truth is the server (list + status). No Drift table, no
SharedPreferences invoice cache, no offline editing.

## Polling with backoff (DG-I4)

The detail screen polls the unsigned status endpoint and the authenticated
fallback projection with exponential backoff (3s → cap ~30s), stops on a
terminal status
(`paid`/`expired`/`cancelled`/`underpaid`/`overpaid`) or on dispose. No tight
loop, no poll after terminal. An invoice with delayed, active, confirming, or
integrity-hold fallback remains under supervision even if its ordinary status
is terminal; only a settled fallback completes that monitoring lifecycle.

## No manual recovery product

The client contains no signed recovery POST, incident-time address picker,
Recover button, confirmation sheet, retry counters, or till-side settlement
instruction. Bullnym executes fallback while the phone can be offline. Mobile
only registers the single automatic destination in the separate
`automatic_fallback` feature and supervises server-authoritative invoice state.

## Existing layout debt

This feature predates the current feature layout and still has an
`application/ports` hexagon. Automatic supervision stays inside that existing
boundary for an atomic change; migrating the whole feature is separate work.

## Multi-rail single-Liquid-address caveat (§3.19)

When both LN and Liquid are enabled, ONE Liquid address serves both the direct
Liquid destination and the LN-swap claim destination (server design). The client
supplies one Liquid address; intentional for v1.

## Deploy gate (§14, LIGHT)

The signed endpoints are gated by the server `features.invoices` flag. The
feature is ready-in-fork and **fails closed** (a clear error, never a silent or
wrong write) against a server without the flag/routes. This feature makes ZERO
server commits.
