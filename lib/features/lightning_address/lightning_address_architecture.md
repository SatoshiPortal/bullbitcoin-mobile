# Lightning Address

Lightning Address owns app-side orchestration for the wallet's permanent Bullnym nym and for turning only the Lightning Address product online or offline. Name ownership is reconstructed from Bullnym and is never persisted locally.

## Scope

This PR owns:

- the public Lightning Address facade;
- domain use cases for capability, prepare wallet, register, delete, lookup/status, wallet-owned registration/status composition, wallet-owned online/offline composition, and receive-readiness lookup;
- deterministic Liquid receive wallet materialization through the Deterministic Wallets facade;
- keychain manifest metadata recording through the Keychain Manifest facade;
- Lightning Address receive-wallet behavior defaults so the Liquid receive wallet is hidden on Home and eligible for generic autosweep;
- mapping Bullnym failures into Lightning Address domain errors;
- routed activation/status UI under Bitcoin settings;
- localized Lightning Address domain and activation copy, documentation, and feature graph edges;
- headless Bullnym, Nostr Identity, and Lightning Address dependency-injection locators so the facade and activation UI are production-composable.

It does not own public identity registration, payment pages, wallet manifest publish, Nostr relay/profile/DM behavior, autosweep execution, registration-state persistence, name replacement, or payment-page receive flows.

## Boundaries

Lightning Address consumes only public facades:

- `features/bullnym/public/bullnym_facade.dart`;
- `features/deterministic_wallets/public/deterministic_wallets_facade.dart`;
- `features/keychain_manifest/public/keychain_manifest_facade.dart`;
- `features/nostr_identity/public/nostr_identity_facade.dart`.

It does not import Bullnym internals, Bullnym signing helpers, Bullnym HTTP adapters, or raw Nostr derivation paths.
Registration and delete derive the Bullnym server-auth public key and signing operation through the role-named Nostr Identity facade methods.

Registration and delete receive `xprvBase58` only inside domain composition so Lightning Address can build a one-shot Bullnym auth signer through Nostr Identity.
They pass the confidential descriptor through to Bullnym registration.
Lookup accepts the Bullnym auth public key/npub hex and does not require wallet secret material.
Lightning Address does not persist or own wallet secrets.
It delegates local wallet creation/reuse to Deterministic Wallets, records recovery metadata through Keychain Manifest, and only handles returned public descriptors for Bullnym registration.

`prepareWallet()` creates or reuses the dedicated Liquid receive wallet from the `lightning_address_wallet_seed` BIP85 reservation, records the resulting wallet materialization in the keychain manifest, and applies product defaults through the generic wallet behavior use case: `hideOnHome: true` and `autoSweepEnabled: true`.
Lightning Address applies those defaults because it owns the product policy, but it does not run sweeps itself.
Actual drain execution remains in `features/autosweep` and is triggered by the wallet sync flow when the synced wallet has autosweep enabled.

Applying `autoSweepEnabled` here opts the Lightning Address receive wallet into the single, locked autosweep policy owned by `features/autosweep`: a 100-sat dust floor, a 3% maximum fee-to-balance ceiling, and a 0.1 sat/vB relative fee rate.
This extends the sweep policy that originally shipped for the BTCPay receive wallet to a second Get Paid product without changing any of its values.
That extension is a deliberate product decision (Get Paid decision [1]), generalized to the whole Get Paid family rather than tuned per product, and is recorded here (and in issue #3) so it is explicit rather than an implicit side effect of enabling autosweep.
Because the policy is shared and unversioned per product, the UI keeps these controls in Advanced settings and does not assert a drain outcome on the primary status screen.
This follows the canonical rollback-timing rule in `ARCHITECTURE.md` (Error handling): the durable manifest record is the commitment point.
If local wallet creation fails before manifest recording, the use case rolls back newly created deterministic wallets best-effort and returns a local preparation error.
Once manifest recording succeeds, defaults failures return a local preparation error without rolling back the wallet, so durable recovery metadata never points at a removed wallet.
Recovered Lightning Address wallets require product reactivation because the manifest can restore wallet materialization metadata but cannot prove an active Bullnym server registration.
Remote recovery therefore calls `ensureRegistrationLive()` automatically. A live registration is left untouched; a legacy inactive registration with a known nym is silently re-registered without scheduling a backup write. Missing registrations require user reactivation, while network and server failures remain explicitly unreachable. An offline permanent-name registration remains offline until an explicit user action; recovery never silently turns it back on. The local manifest restores wallet materialization metadata but is not an ownership or product-availability record.

The existing `xprvBase58` and confidential descriptor registration inputs remain foundation inputs for internal protocol use cases.
They are not exported by the public facade and must not be passed from routed UI.
`RegisterWalletOwnedLightningAddressUsecase` is the product-safe registration composition point: it accepts only a nym, applies the exact shared Bullnym normalization/validation before local side effects, derives the default-wallet xprv behind a Lightning Address port, prepares or reuses the dedicated Liquid wallet, and submits the prepared wallet's confidential descriptor through the protocol registration use case.
`DeactivateWalletOwnedLightningAddressUsecase` derives the same wallet-owned auth material and calls Bullnym delete with the already-owned nym. Delete turns only Lightning Address payments offline; it does not release the nym or archive Payment Page or Point of Sale.
`LookupWalletOwnedLightningAddressRegistrationUsecase` is the matching product-safe status path; it derives the same wallet-owned auth material internally, derives the Bullnym auth public key, and returns Bullnym's nym/active status plus a canonical Lightning Address only when Bullnym supplies one, without exposing xprv input.

If local default-wallet xprv derivation or wallet preparation fails, no Bullnym registration is attempted.
If Bullnym registration fails after wallet preparation, the wallet-owned registration use case throws `WalletOwnedLightningAddressRegistrationException` with the prepared wallet id, whether it was created in the attempt, and whether the failure is an uncertain post-submission transport/response failure.
Lightning Address keeps the prepared deterministic wallet and local manifest entry for retry/status reconciliation; it does not invent rollback semantics for a request that may have reached the server.

The routed activation/status UI lives under Bitcoin settings.
Its Cubit reads `GET /version` capability before registration state. Claim and availability controls exist only when the exact `permanent_names_v1` policy is advertised; an old, unavailable, or inconsistent server fails closed without blocking the rest of the app.
The first lifetime claim is normalized, explained as permanent in the form, submitted without a second confirmation dialog, and refreshed from the server after submission. Once lookup returns an owned nym, presentation can only turn the Lightning Address product online with the same nym or offline through delete.
The activation use case maps wallet-owned registration failures to an activation-safe Lightning Address exception that keeps wallet-id metadata out of the presentation contract while preserving local-preparation versus uncertain post-submission failure semantics.
The readiness use case combines the wallet-owned Bullnym status lookup with local receive-wallet preparation only when the server registration is active, so an active server registration can repair local receive readiness without exposing wallet metadata to the UI.
Local setup failures during active-status readiness are represented as `activeLocalSetupFailed` so the user can retry local setup without being told the server registration is inactive.
The primary UI shows availability and the canonical server-owned Lightning Address without exposing the internal nym, quota, lookup, or wallet-readiness fields. Tapping the address opens its QR and copy view, long-press copies it, and Advanced settings contains the online switch and local wallet behavior controls. Active and inactive states retain the same address identity. If an older or malformed lookup omits the address, the UI shows an explicit retryable incomplete state instead of synthesizing a domain or claiming that the address is fully available.
It does not pass xprv material, descriptors, wallet ids, Nostr handles, Bullnym internals, autosweep internals, or raw protocol use cases through presentation or route state.

Lookup reflects the Bullnym public lookup contract: with the exact permanent-name policy it reports the permanent nym, Lightning Address online status, quota, and the canonical Lightning Address for both online and offline permanent nyms. The mobile parser keeps the address optional for compatibility with older responses, while presentation treats its absence as incomplete and recoverable. Lookup policy is a post-registration consistency check; pre-registration capability comes only from `/version`.
Lightning Address does not synthesize a copyable address from a hardcoded domain.

The local nym validator trims surrounding whitespace, lowercases before confirmation/signing, enforces the shared 1–32 ASCII lowercase-letter/digit/internal-hyphen grammar, and applies Bullnym's reserved-nym prefilter. The server remains authoritative for races and stable conflict codes; presentation never displays its diagnostic reason strings.
