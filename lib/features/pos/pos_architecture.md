# Point of Sale (`features/pos`)

Provisions a **keyless PWA till terminal** from the mobile app. The merchant
creates a POS (a `(nym, kind='pos')` row + BIP85 wallet-seed **index 103**), and
the app hands back a **shareable terminal URL** (`{base}/{nym}/pos`). The browser
terminal and invoice minting are entirely server-side; the app renders no till.

This feature is the POS analogue of `features/payment_page` (the Donation Page).
It is a SEPARATE flow (UX-SEP): its own hexagon, entry tile, screen, and routes.
It REUSES the shared bullnym donation-page client with `kind='pos'` — it adds no
new client and no new signing action.

## Three-wallet routing (DG-6)

One nym owns up to three wallets under one seed:

| Product          | Wallet (BIP85 index) | Server row              |
|------------------|----------------------|-------------------------|
| Lightning Address| 101 (`users.ct_descriptor`) | the registration |
| Donation Page    | 102                  | `(nym, 'payment_page')` |
| **Point of Sale**| **103**              | **`(nym, 'pos')`**      |

POS sales settle to wallet **103**, never 101/102. The `nym@domain` Lightning
address still settles to the **Lightning Address wallet (101)** even for a
POS-only nym (ROUTE-3W); the provisioning screen states this in product copy.

## Money-safety invariants

- **KR-1 always-descriptor (sharper for POS).** Every `kind='pos'` save carries
  the wallet-103 `ct_descriptor`, non-empty, read solely from the prepared 103
  wallet's `externalPublicDescriptor`. `ProvisionPosUsecase` asserts it non-empty
  (`EmptyPosDescriptor`) BEFORE signing/wire, and it is the ONLY save call site,
  so a descriptorless kind=pos save cannot be constructed. Unlike the page, the
  server has **no LA-cursor fallback** for the pos branch — it hard-rejects a
  descriptorless save (`DonationPageInvalid`). Sales therefore route to 103 only.
- **kind-scoping total.** Provision / archive / GET all pin `kind='pos'`;
  `pos_mode` is never sent (POS is a kind, never a mode). The signed byte layout
  is PR25's `donation-page-save`/`-archive` verbatim with `kind='pos'` LAST.
- **KC-6 posture.** Wallet 103 is hidden + autosweep-ON on create AND on recovery
  (the PR23 restore path re-applies it to every classified reservation).
- **Manifest-record-before-fundable + rollback.** `PreparePosWalletUsecase`
  records the reserved derivation before applying posture; a record failure rolls
  the wallet back best-effort. Re-prepare is idempotent (`created:false`).
- **Coexistence non-interference (DELTA 4).** Provisioning/archiving the POS
  touches only `(nym,'pos')` + wallet 103; it never reads or writes the page row,
  wallet 102, or wallet 101 (beyond the shared read-only nym lookup).

## Terminal-URL source (DG-P5)

The terminal URL is **constructed client-side** as `{bullnymBaseUrl}/{nym}/pos`
(the base is the same value the shared bullnym client is configured with; the nym
is our own resolved registration). No server-echoed `public_url` is trusted into
this string, so a hostile/oversized server value can never become the terminal
URL. `PosTerminal.fromBullnym` builds it; a server `public_url` for a kind=pos row
is advisory only. The URL is surfaced as text + copy-to-clipboard + guarded
external launch (`LaunchMode.externalApplication`) — never webviewed, no QR
(DG-P4). **Server contract note:** whether the save/GET response echoes a
`/:nym/pos` `public_url` is UNVERIFIED; client-side construction sidesteps it.

## Recovery heal (DG-3, READ-ONLY)

`EnsurePosLiveUsecase` mirrors the page heal: look up the (shared) registration →
GET the pos row (kind-scoped) → classify. Present & not archived ⇒ `live` (silent);
archived ⇒ `archivedByUser` (respect it); registration live but row absent (or no
nym) ⇒ `needsReactivation` (one-tap re-provision — label/currency are unknowable
client-side, so silent re-create is impossible); network/timeout/server ⇒
`unreachable` (loud). It NEVER issues a save (a save would clear `archived_at`) and
publishes no backup. `HealRecoveredProductsUsecase` runs it when the restore flags
`pos_wallet_seed` for reactivation.

## Stateless-local (no drift table)

Source of truth is the server row (read back via GET kind=pos). There is no local
POS store, no SharedPreferences for POS content, no offline editing.

## No in-app terminal (DELTA 2)

The app renders no till UI, mints no invoices, embeds no webview of the terminal,
and collects no page content (description/socials/website/image). The POS label
rides the shared `header` slot; the other content fields are sent as `''`.

## Deploy gate (KR-2, DG-P7)

The feature is inert-but-safe: `kind='pos'` saves fail CLOSED (AuthError) against
a pre-release server. Go-live is deploy-gated on pay2 carrying the ISS-S-02
release; that is a Francis-owned ops gate. PR26 makes zero server commits.
