# Point of Sale (`features/pos`)

Provisions a **keyless PWA till terminal** from the mobile app. The merchant creates a POS (a `(nym, kind='pos')` row + BIP85 wallet-seed **index 103**), and the app hands back a server-owned, validated **shareable terminal URL**. The browser terminal and invoice minting are entirely server-side; the app renders no till.

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

## Permanent names, availability, and terminal URL

The screen reads `/version` before ownership and exposes permanent-name and availability UX only for exact `permanent_names_v1`. It reconstructs the nym and optional alias from the authenticated Lightning Address owner lookup, regardless of whether Lightning Address itself is online. Nym claims remain owned by the Lightning Address flow. POS may make the one optional lifetime alias claim; the alias is shared with Donation Page and becomes permanently read-only. The client can express only preserve or first claim—not clear, rename, replace, release, deactivate, reactivate, or reassign.

The terminal URL comes from the save/GET response and is validated by the shared Bullnym boundary against the trusted public origin, response nym/alias, and exact POS route. Without an alias it is `/:nym/pos`; with an alias it is `/a/:alias/pos`. Nym routes remain valid server-side. The product never rebuilds the URL from configuration. It surfaces the validated URL as text, copy-to-clipboard, and guarded external launch—never a webview or QR (DG-P4).

The POS online switch writes only `kind=pos`: off is a signed soft archive and on is a provision/save that revives that row. Lightning Address and Donation Page availability are independent, and turning POS off never changes permanent name ownership.

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

Source of truth is the server row (read back via GET kind=pos) plus authenticated owner status for permanent names. There is no local POS/name store, no SharedPreferences for POS content or alias ownership, and no offline editing. After an app-state wipe, owner lookup reconstructs the same shared alias.

## No in-app terminal (DELTA 2)

The app renders no till UI, mints no invoices, embeds no webview of the terminal,
and collects no page content (description/socials/website/image). The POS label
rides the shared `header` slot; the other content fields are sent as `''`.

## Deploy gate (KR-2, DG-P7)

The feature remains fail-closed unless pay2 advertises the exact permanent-name contract, and `kind='pos'` signing/response validation remains mandatory. Server deployment is an ops gate outside this mobile slice.
