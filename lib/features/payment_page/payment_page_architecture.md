# Payment Page (Donation Page)

The hosted Donation Page: a recipient with a Bull nym gets a bullnym-hosted
public page that anyone can pay through anonymous checkout. User-facing copy
calls it the "Donation Page"; the code namespace, routes, BIP85 reservation, and
server `kind` stay `payment_page` (a frozen namespace and server contract).

## Three-wallet routing (DG-6 / ROUTE-3W)

There is ONE nym per seed, with three separate product wallets:

- Lightning Address → wallet 101 (`users.ct_descriptor`). The `nym@domain`
  Lightning address resolves HERE, never to the page.
- Donation Page → wallet **102** (`donation_pages.ct_descriptor`,
  `kind=payment_page`, keyed `(nym, kind)`). Reached via its OWN public URL and
  settles to its OWN wallet.
- POS → wallet 103 (`kind=pos`, a future PR). Not built here.

Product copy states this explicitly: the Lightning address pays the Lightning
Address wallet; the Donation Page has its own link and its own wallet.

## Always-descriptor (KR-1)

Every `PUT /donation-page` this feature emits carries the wallet-102
`ct_descriptor` (non-empty, the wallet's external public descriptor). The save
usecase sources it solely from the prepared wallet — there is no code path that
sends an empty descriptor, and there is no other PUT call site. An empty
descriptor would let the server fall back to the Lightning Address wallet and
silently route page funds to wallet 101.

## kind-scoping (KR-2/KR-3)

Save, archive, and GET all pin `kind=payment_page`. The signed save payload
appends the optional-trailing fields in the server's exact order with `kind`
LAST; `pos_mode` is never sent. The golden byte-layout tests in the bullnym
feature pin the layout; a kind-aware server fails a mis-signed request closed
with `AuthError`.

## Wallet 102 lifecycle

`PreparePaymentPageWalletUsecase` clones the Lightning Address prepare pattern:
derive via the `payment_page_wallet_seed` reservation (index 102), record the
keychain-manifest entry BEFORE the wallet is fundable, roll back best-effort if
recording fails, then apply the KC-6 posture (hidden on home + autosweep on).
It is idempotent — a re-prepare returns the existing wallet without re-deriving
or re-recording. A fundable-102-without-recovery-record state is impossible.

## Single off-switch (DG-3)

The UI exposes ONE off-state: Deactivate = a signed archive (soft-delete;
public URL shows a deactivation notice). Saves always send `enabled: true`;
republishing is a save that revives the archived row. There is no separate
`disabled` state and no `ct_descriptor: ''` code path.

## Stateless-local model

The page's source of truth is the server row, read back via the public GET.
There is NO local drift table and NO SharedPreferences state for page content —
the wallet, its manifest record, and the remote row ARE the state (the Lightning
Address model). No offline editing.

## Recovery heal (DG-3, §3.12)

`EnsurePaymentPageLiveUsecase` is READ-ONLY. On recovery it looks the nym up
(shared LA registration), GETs the page (kind-scoped), and classifies:
`live`/`archivedByUser` → silent; page row genuinely missing (or no nym) →
`needsReactivation` (one-tap recreate — the content is unknowable client-side,
so a silent re-create is impossible); network/timeout/server → `unreachable`
(loud, never fake-live). It NEVER issues a PUT (a save would clear
`archived_at` — a resurrect/clobber hazard) and never re-registers.

## Display currency (DG-5)

The editor live-fetches `/api/v1/supported-currencies` on load. On failure it
degrades: an existing page keeps its stored currency (read-only) and a new page
defaults to CAD with a retry affordance. The list is never hardcoded (the
prototype's INR drift bug).

## Social-preview description

The existing signed `description` field is the Donation Page's short description; there is no separate social-only wire field.
The editor requires 1-120 user-perceived Unicode characters and applies the server's 512-byte safety ceiling.
It explains that the text appears on the Page and when its link is shared.
Bullnym owns image rendering and always adds the fixed Bull Bitcoin logo; mobile neither uploads nor signs image bytes.

Archived legacy Pages remain editable before re-publication so descriptions that predate the 120-character contract can be shortened instead of stranding the Page in an unrecoverable archived state.

## Anti-scope

No POS (`kind=pos`, index 103) anything; no Invoices or dashboard hub; no image
upload (this fork does not manage the OG/avatar images); no QR / save-to-gallery
(copy-to-clipboard + external open only). POS will reuse the shared bullnym
donation-page client with `kind=pos` in a later PR — this feature adds the
kind-parameterized seam but no POS values.
