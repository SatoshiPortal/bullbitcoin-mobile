# Fiat Settlement — Architecture

Merchants configure, per Get Paid product (Lightning Address, Payment Page, POS,
Invoices), what fraction of each received payment Bull Bitcoin converts to a
fiat balance (0% Bitcoin-only, 1–99% mixed, 100% fiat-only) and in which of the
seven approved currencies (CAD, EUR, MXN, CRC, COP, ARS, USD).

## Ownership boundary

The client only submits signed configuration and renders server-owned results.
It performs **no** eligibility, KYC, FX, minimum, routing, or order logic, and
never creates or polls sell orders. Bull Bitcoin (via Bullnym) runs the single
eligibility preflight atomically at save time and owns all settlement.

## Scoped credential confidentiality

The scoped `SELL_TO_FIAT_BALANCE` key is imported and stored by `core/exchange`
(bound to the Bull Bitcoin `userId`, per environment). This feature reaches it
only through `ScopedSettlementKeyPort`:

- `isPresent()` — the only signal exposed to gating/UI.
- `readPlaintext()` — called from `SetFiatSettlementUsecase` alone, once per
  submission, and only when Bullnym has **no** active credential. The value is a
  local variable handed straight to the Bullnym transport; it never enters
  cubit/UI state, route arguments, logs, analytics, or errors, and there is no
  reveal/copy/export path.

## Capability gating

`GetFiatSettlementCapabilityUsecase` reads the public, unsigned Bullnym options
endpoint. HTTP 404 (old server) → unsupported; otherwise the advertised
`accepting_new_settings` decides whether new activations may be offered.
Disabling (percentage 0) stays available regardless. Terms/disclosure text is
client-side localized content, not read from the server.

## Layers

```
public/    → FiatSettlementFacade (the only cross-feature entry point)
domain/    → entities, sealed FiatSettlementFailure, transport→feature mapping,
             ports (default-wallet xprv, scoped key), usecases
data/      → xprv adapter, scoped-key adapter
```

The npub-wide signer is derived per request from the default wallet xprv via
`NostrIdentityFacade` (role `bullnymServerAuth`) and is never stored.

## Error model

`FiatSettlementFailure` is the closed set the presentation layer renders into
the exact validated action sets: `kycRequired`, `credentialProblem`,
`dependencyUnavailable` (503), `bullnymUnreachable` (network/timeout),
`invalidInput`, `unexpected`. Stable server codes: `FIAT_CONVERSION_KYC_REQUIRED`,
`BULL_BITCOIN_CREDENTIAL_REQUIRED`, `BULL_BITCOIN_CREDENTIAL_INVALID`.
