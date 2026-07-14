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
- POS → wallet 103 (`kind=pos`).

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

## Permanent names and exact capability gate

The screen reads `/version` first and exposes all name and availability UX only for the exact `permanent_names_v1` contract. Ownership is then reconstructed from the authenticated Lightning Address owner lookup; no name is stored by this feature. The nym is claimed only in Lightning Address settings. Donation Page may optionally make the account's one lifetime alias claim. That alias is shared with POS, read-only after claim, and can never be cleared, renamed, replaced, released, deactivated, reactivated, or reassigned. Omitting the alias from a save means preserve; the client has no clear/replace intent.

Without an alias, the Page uses the server-returned nym route. With one, its canonical URL is the server-returned `/a/:alias` route. The shared Bullnym boundary validates the trusted origin and exact route before the product model accepts it; the mobile feature does not reconstruct public URLs.

## Independent availability (DG-3)

The Page's online switch writes only `kind=payment_page`: off is a signed soft archive and on is a save that revives that row. Lightning Address and POS stay as they are, and permanent nym/alias ownership never changes. Saves always send `enabled: true`; there is no separate disabled state or `ct_descriptor: ''` path.

## Stateless-local model

The page's source of truth is the server row, read back via the public GET. There is NO local drift table and NO SharedPreferences state for page content or public-name ownership — the wallet, its manifest record, authenticated owner lookup, and remote row are the state. An app-state wipe therefore reconstructs the same permanent alias from Bullnym. No offline editing.

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

No Invoices or dashboard hub; no image upload (this fork does not manage the OG/avatar images); no QR / save-to-gallery (copy-to-clipboard + external open only). POS remains a separate feature and wallet; the only shared product state is the server-owned permanent alias.
