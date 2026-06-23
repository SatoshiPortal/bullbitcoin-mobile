# `send` — error-sanitization refactor plan (#1895)

> Status: **draft for review — no code changed yet. Re-verified against the codebase (see §0).**
> Branch: `refactor-send-errors`. Target: `develop`. This is one of the
> three "monster" features (its own PR + tests per the rollout plan).
> Standard reference: AGENTS.md + ARCHITECTURE.md "Error handling", and the
> shipped reference features `import_watch_only`, `app_unlock`,
> `broadcast_signed_tx`.

---

## 0. Verification pass (re-analysis results)

Re-checked every load-bearing assumption against the code. Outcomes:

- ✅ **`SendState.error` is never read** anywhere in the repo (the other
  `state.error` hits belong to autoswap/legacy_seed_view/swap/ark cubits). Safe
  to drop; the 4 writers become `log.*`.
- ✅ **Two classes named `SendConfirmScreen`.** The send feature's confirm step
  (`send_screen.dart:63 → SendConfirmScreen :664`) renders the feature's own
  `_SendError` (`:718/:731`) — **generic localized keys, already sanitized**.
  The **core** `lib/core/screens/send_confirm_screen.dart` contains
  `CommonConfirmSendErrorSection` (`:705`) which **does** render
  `_buildError.message` / `_confirmError.message` raw (`:730/:754`) — but it is
  consumed by **`swap`** (`swap_confirm_page.dart`), not by the send confirm
  step. It also binds the **core** `send_errors.dart` exception types, not the
  send feature's inline ones. ⇒ **Out of scope for this PR** (core/swap concern;
  core migrates last). Flag it for the swap PR. No cross-type coupling: the send
  feature never passes its state exceptions into a core widget.
- ✅ **`sendErrorBalanceTooLowForMinimum` is comment-only** (`send_state.dart:500`),
  never rendered. The "balance too low for minimum" `SwapLimitsException`
  (`send_cubit.dart:1757`) carries `minLimit`, so today it renders via
  `sendErrorAmountBelowMinimum`. ⇒ `SendSwapLimitsFailure{minLimit, maxLimit,
  suggestInstantPayments}` reproduces **every** swap-limit message exactly; all
  swap-limit rendering funnels through `_getSwapLimitsErrorMessage` +
  the `suggestInstantPayments` widget (`send_screen.dart:471/:485/:1977`).
- ✅ **`copyWith(field: null)` already used** (clearAllExceptions `:143–148`,
  backClicked `:160`, `_setSelectedWallet` `:1801`) ⇒ freezed's `freezed`
  sentinel handles explicit-null today; retyping the slots (or a single field)
  preserves it. No freezed concern.
- ✅ **`NoSpendableUtxoException`** is rethrown by the prepare use-cases and
  currently falls through `createTransaction`'s generic `catch` →
  `BuildTransactionException(e.toString())` → generic `sendErrorBuildFailed` (no
  distinct UI). ⇒ map it to `SendBuildTransactionFailure` to preserve behavior.
- ✅ **`request_identifier` is fully isolated** — its own route + its own
  `RequestIdentifierCubit` (`send_router.dart:40`), not the `SendCubit`. Phase 2
  is genuinely standalone.
- ✅ **`meta: ^1.17.0`** present; `@useResult` already used by the reference
  features. No dependency work.
- ✅ **No new l10n keys** needed (all 16 referenced keys exist). Only candidate
  for pruning: the `sendErrorBalanceTooLowForMinimum` *key* (comment-only usage)
  — verify it is truly unreferenced before removing; otherwise leave it.

**Online check:** none was required. Every open question was codebase-specific
and resolved above; the design relies only on stable Dart 3 sealed-class /
switch-exhaustiveness features and the hand-rolled `Result` already shipped in
`lib/core/utils/result.dart` — no 2026 library/API choice is in question.

---

## 1. Goal & scope

Bring `lib/features/send` onto the `Result<T, Failure>` standard so **no raw
exception text reaches the UI**, with **minimal behavioral change**. The send
flow is deep (5 steps, lightning + chain swaps + payjoin + sendMax) so the
overriding constraint is **regression avoidance**, not maximal purity.

In scope:
- `lib/features/send/**` (cubit, state, use-cases, UI, the `request_identifier`
  sub-flow, locator).
- A new `domain/send_failure.dart` (pure) + `presentation/send_failure_l10n.dart`.
- New unit tests (none exist today).

**Out of scope (do NOT touch):**
- `lib/core/errors/send_errors.dart` — **shared core infra**, imported by
  `swap`, `core/blockchain`, `core/swaps`, `core/screens`. `BroadcastTransactionException`
  lives here and stays. Core repos are migrated last per the rollout; the send
  feature only maps their throws at its own boundary.
- The wrapped core repositories/use-cases themselves (Wallet, Bitcoin, Liquid,
  Boltz, Payjoin, fees). They keep throwing; send catches at the first layer it
  owns.

---

## 2. Current state (audited)

### 2.1 The actual user-visible leaks (narrower than the field count)

Only **three** raw-text paths actually reach a user today:

| # | Where | Code | Leak |
|---|-------|------|------|
| L1 | `send_screen.dart:255` `AddressErrorSection` | `swapError.message` fallback | raw swap-creation message |
| L2 | `send_screen.dart:1974` `_swapCreationErrorMessage` | `return error.message` fallback | raw swap-creation message |
| L3 | `request_identifier_cubit.dart:15,30` → `request_identifier_screen.dart:140` | `emit(error: e.toString())` rendered | raw `PaymentRequest.parse` reason |

Everything else is **already sanitized at the UI** (build/confirm errors render
fixed `sendErrorBuildFailed` / `sendErrorConfirmationFailed` regardless of the
carried message), or **silently swallowed**:

- `SendState.error` (`Object?`) is written by 4 `catch (e) { emit(error: e.toString()) }`
  sites (`loadWalletWithRatesAndFees`, `amountChanged`, `loadUtxos`, `loadFees`)
  but **is never read in any widget**. Confirmed silent. Today these failures
  are invisible; we will log them instead of swallowing.

> Implication: this refactor both **closes L1–L3** and **improves** the
> swallowed paths (they get logged). It is a net behavior improvement, but the
> only *visible* change to a user is L1–L3 going from raw text → localized text.

### 2.2 State today (`send_state.dart`)

Six typed exception slots + one generic, all `BullException` subclasses defined
**inline** in `send_state.dart:466–531`:

```
swapCreationException        : SwapCreationException?   (subtypes: Amountless, Expired, HardwareWallet)
insufficientBalanceException : InsufficientBalanceException?
invalidBitcoinStringException: InvalidBitcoinStringException?  (subtype: UnsupportedQrFormat)
swapLimitsException          : SwapLimitsException?     (carries minLimit / maxLimit / suggestInstantPayments)
buildTransactionException    : BuildTransactionException?
confirmTransactionException  : ConfirmTransactionException?    (carries isBroadcastFailure)
error                        : Object?                  (generic, never rendered)
```

Note `SwapCreationException` / `InsufficientBalanceException` etc. are **also**
declared in core `send_errors.dart`; the inline copies in `send_state.dart`
shadow them. Only the inline copies are removed by this work.

### 2.3 Cubit today (`send_cubit.dart`, 1814 lines)

- It is the orchestration boundary. ~15 `try/catch` sites.
- It calls **10 send use-cases** + many core use-cases. Each send use-case
  `throw`s a `BullException` subtype after wrapping a core repo.
- Write sites per field (grep counts): swapCreation 11, swapLimits 10,
  insufficientBalance 7, buildTransaction 7, confirmTransaction 7, error 7,
  invalidBitcoinString 5.
- **Control-flow guards that read exception fields (regression-critical):**
  - `send_cubit.dart:339` `... || state.swapCreationException != null) return;` (after `handleChainSwap`, MRH branch)
  - `send_cubit.dart:455` same triple-guard (bip21 branch)
  - `send_cubit.dart:1022` same triple-guard (`onAmountConfirmed`)
  - `send_cubit.dart:1044` `if (state.buildTransactionException == null) { ...advance to confirm }`
  - `send_cubit.dart:1550` `if (state.confirmTransactionException == null) { step = sending }`
  - `send_cubit.dart:1559` `if (state.confirmTransactionException != null) { step = confirm; return }`
  - `clearAllExceptions()` (`:140`) nulls all six together; called at the top of
    most user actions.

  These 6 reads are the **entire** control-flow surface. Any chosen state shape
  must preserve their exact truth values.

### 2.4 Foreign throw surface (what the boundary must map)

From tracing every wrapped call (see appendix A). The catch must be **broad**
(`catch (e, st)`), because the surface mixes:
- `BullException` subtypes (`PrepareBitcoinSendException`, `GetWalletException`,
  `BroadcastTransactionException`, `NotEnoughFundsException`, `NoSpendableUtxoException`, …)
- raw `throw Exception('...')` (e.g. `CreateChainSwapToExternalUsecase`, prepare guards)
- raw `throw e.toString()` — a **String**, not an Exception (`DecodeInvoiceUsecase:13`)
- unwrapped **BDK / LWK / Boltz** SDK errors bubbling through repos.

Types the cubit currently catches *by type* and must keep distinguishing:
`NotEnoughFundsException`, `PrepareBitcoinSendException`,
`PrepareLiquidSendException`, `GetWalletException`,
`BroadcastTransactionException`, `NoSpendableUtxoException`.

### 2.5 Feasibility constraint — not every use-case can return `Result`

Some use-cases are consumed in shapes that don't compose with `Result`:

- **Record `.wait` tuples**: `loadSwapLimits` (`:651–657`, `:668–674`) and
  `getCurrencies` (`:765–768`) call `GetSwapLimitsUsecase` /
  `ConvertSatsToCurrencyAmountUsecase` / `GetAvailableCurrenciesUsecase` inside
  `(a, b).wait`. Converting these to `Result` breaks the tuple ergonomics.
- **Streams**: `WatchSwapUsecase`, `WatchFinishedWalletSyncsUsecase`,
  `WatchWalletTransactionByTxIdUsecase` return `Stream`, handled in `.listen`.
  Not a leak path; leave as-is.
- **Best-effort loaders** feeding the unused `state.error`
  (`getCurrencies`/`getExchangeRate`/`loadFees`/`loadUtxos`): their failures are
  invisible today. They become **log-only** (no `Result` needed).

> Conclusion: **convert to `Result` only the use-cases whose failures are
> user-visible** (the prepare/sign/create-swap/chain-swap/broadcast/parse/
> select-wallet/decode chain). For the rest, replace
> `catch (e) { emit(error: ...) }` with `catch (e, st) { log... }`. This is the
> single biggest risk-reducer in the plan.

---

## 3. Target design

### 3.1 `domain/send_failure.dart` (pure Dart, Flutter-free)

`sealed class SendFailure extends Failure`, with one variant per current
user-visible exception, **carrying the same data** so UI logic survives:

```dart
sealed class SendFailure extends Failure { const SendFailure([super.logMessage]); }

// address step
final class SendInvalidPaymentRequestFailure extends SendFailure { const ...([super.logMessage]); }
final class SendUnsupportedQrFormatFailure  extends SendFailure { const ...(); }
final class SendInsufficientBalanceFailure  extends SendFailure { const ...([super.logMessage]); }

// swap creation
final class SendSwapCreationFailure   extends SendFailure { const ...([super.logMessage]); }
final class SendAmountlessInvoiceFailure extends SendFailure { const ...(); }
final class SendExpiredInvoiceFailure  extends SendFailure { const ...(); }
final class SendHardwareWalletSwapFailure extends SendFailure { const ...(); }

// swap limits — fields first, then ctor (AGENTS member ordering)
final class SendSwapLimitsFailure extends SendFailure {
  final int? minLimit;
  final int? maxLimit;
  final bool suggestInstantPayments;
  const SendSwapLimitsFailure({this.minLimit, this.maxLimit,
      this.suggestInstantPayments = false, String? logMessage}) : super(logMessage);
  bool get isBelowMinimum => minLimit != null;
  bool get isAboveMaximum => maxLimit != null;
}

// build / confirm
final class SendBuildTransactionFailure extends SendFailure { const ...([super.logMessage]); }
final class SendConfirmTransactionFailure extends SendFailure {
  final bool isBroadcastFailure;
  const SendConfirmTransactionFailure({this.isBroadcastFailure = false, String? logMessage}) : super(logMessage);
}

// catch-all → generic message only
final class SendUnexpectedFailure extends SendFailure { const ...([super.logMessage]); }
```

These map 1:1 onto the current exceptions, so the existing `sendError*` keys all
still apply (no new l10n keys — verified all 16 exist).

### 3.2 `presentation/send_failure_l10n.dart`

Exhaustive `toTranslated(BuildContext)` switch reusing existing keys, e.g.:

```dart
SendInvalidPaymentRequestFailure() => context.loc.sendErrorInvalidAddressOrInvoice,
SendUnsupportedQrFormatFailure()   => context.loc.sendErrorUnsupportedQrCodeFormat,
SendInsufficientBalanceFailure()   => context.loc.sendErrorInsufficientBalanceForPayment,
SendAmountlessInvoiceFailure()     => context.loc.sendErrorInvoiceMustContainAmount,
SendExpiredInvoiceFailure()        => context.loc.sendErrorInvoiceExpired,
SendHardwareWalletSwapFailure()    => context.loc.sendErrorHardwareWalletCannotSwap,
SendSwapCreationFailure()          => context.loc.sendErrorSwapCreationFailed,
SendSwapLimitsFailure(:final minLimit, :final maxLimit) => /* below/above/default keys */,
SendBuildTransactionFailure()      => context.loc.sendErrorBuildFailed,
SendConfirmTransactionFailure()    => context.loc.sendErrorConfirmationFailed,
SendUnexpectedFailure()            => context.loc.oopsSomethingWentWrong,
```

`suggestInstantPayments` and `isBroadcastFailure` are read by the UI for
*layout* (extra widget / extra line) via pattern-match on the variant — allowed
(presentation reading a typed domain value, like today's `isBroadcastFailure`).

### 3.3 State shape — **the one open decision** (see §6)

Recommended (lowest-risk): **keep the existing slots, retype them** from the
`BullException` subclasses to the matching `SendFailure` subtypes; drop
`error`. The six guards (§2.3) stay byte-for-byte identical; UI selectors keep
their structure and only swap `.message` → `failure.toTranslated(context)`.

Alternative (max convergence): a single `SendFailure? failure`. Matches the
reference features, but rewrites all 6 guards into `is` checks and forces each
UI zone to type-filter which variants it renders — more churn, more chance of a
guard misfire. Defer unless reviewer insists.

---

## 4. Phased execution (each phase independently compilable + reviewable)

### Phase 0 — foundations (already present)
`Result`, `Ok`/`Err`, `Failure` base exist. `core_failure.dart` is **empty** —
do not depend on a shared `CoreFailure`; keep cross-cutting modes (insufficient
funds, etc.) send-local for now.

### Phase 1 — additive failure family (no behavior change)
- Add `domain/send_failure.dart` + `presentation/send_failure_l10n.dart`.
- Nothing references them yet. Compiles, ships green. Easy to review in isolation.

### Phase 2 — `request_identifier` sub-flow (isolated warm-up, closes L3)
- Smallest, fully self-contained leak. Extract a
  `ParsePaymentRequestUsecase` returning `Result<PaymentRequest, SendFailure>`
  (or map inline in the cubit boundary).
- `RequestIdentifierState.error: String` → `SendFailure? failure`.
- Two screens render `failure.toTranslated(context)`.
- Add a use-case test (bad input → `SendInvalidPaymentRequestFailure`, no leak).

### Phase 3 — convert the user-visible use-cases to `Result<T, SendFailure>`
One use-case per commit; each maps foreign throws locally (`try/catch → log
raw → Err`) and gets a sanitization test. Order (leaf-first):
1. `detect_bitcoin_string_usecase` → `SendInvalidPaymentRequestFailure`
2. `select_best_wallet_usecase` → `SendInsufficientBalanceFailure` (maps `NotEnoughFundsException`)
3. `prepare_bitcoin_send_usecase` / `prepare_liquid_send_usecase` → `SendBuildTransactionFailure`
   (preserve `NoSpendableUtxoException` distinction if it drives anything)
4. `sign_bitcoin_tx_usecase` / `sign_liquid_tx_usecase` → `SendConfirmTransactionFailure`
5. `calculate_bitcoin/liquid_absolute_fees_usecase` → map to build/unexpected
6. `create_send_swap_usecase` → swap-creation variants
7. (chain swap / decode invoice / verify amount are core use-cases — wrap their
   throws in the cubit boundary, see Phase 4)

Leave watchers, `.wait`-tuple use-cases, and best-effort loaders unchanged in
signature.

### Phase 4 — `SendCubit` consumes `Result` via `switch`; store `SendFailure`
- Replace each converted call's `try/catch` with an exhaustive `switch`.
- For core-use-case throws still caught by the cubit (chain swap, decode,
  broadcast, payjoin), keep a **single** boundary `try/catch` per orchestration
  method that maps to the right `SendFailure` (this is "the first layer the
  feature owns" — permitted by the standard, as in broadcast_signed_tx).
- Map the by-type catches: `GetWalletException`/`BroadcastTransactionException`
  → `SendConfirmTransactionFailure(isBroadcastFailure: true)`;
  `PrepareBitcoin/LiquidSendException` → `SendBuildTransactionFailure`;
  `NotEnoughFundsException` → `SendInsufficientBalanceFailure`.
- Replace the 4 `emit(error: e.toString())` with `log.warning/severe(...)`.
- Preserve the 6 guards exactly (slot shape → unchanged; single-field → typed `is`).
- Keep all hardcoded English swap-limit strings out of failures — the `min/max`
  values already drive localized text; pass only the numbers + `logMessage`.

### Phase 5 — UI: translate only
- `AddressErrorSection`: drop `swapError.message`; render
  `failure.toTranslated(context)` (keep the per-zone variant filtering).
- Amount-step error: replace `_getSwapLimitsErrorMessage` /
  `_swapCreationErrorMessage` with `toTranslated`; keep `suggestInstantPayments`
  widget via `failure is SendSwapLimitsFailure && failure.suggestInstantPayments`.
- `_SendError`: render via `toTranslated`; keep the `isBroadcastFailure` extra
  line via the typed variant.
- Delete the two helper functions once unused.

### Phase 6 — cleanup + tests + verify
- Delete the inline exception classes in `send_state.dart` (NOT core `send_errors.dart`).
- Remove now-unused imports (`bull_exception.dart`, the `BroadcastTransactionException`
  show-import once mapped).
- Prune any `sendError*` keys that became dead (run a usage grep before deleting).
- Full test pass + `dart analyze`; manual smoke per §5.

---

## 5. Regression checklist (verify each path end-to-end)

Manual + (where possible) widget/unit coverage:
1. Invalid address / invoice typed and scanned → localized invalid msg (not raw). **[L1/L3]**
2. Unsupported QR format → `sendErrorUnsupportedQrCodeFormat` (distinct from invalid).
3. Amountless bolt11 → invoice-must-contain-amount.
4. Expired invoice → expired msg.
5. Hardware-wallet swap attempt → hardware-cannot-swap msg.
6. Amount below / above swap limit (lightning **and** chain) → min/max localized
   text **with the right number**, and the "instant payments" hint when applicable.
7. Insufficient balance at address step and at amount-confirm.
8. Build failure (bad utxo selection / drain) → generic build-failed; **flow stays
   on amount step** (guard `:1044`).
9. Sign failure → confirmation-failed; flow returns to confirm (guards `:1550/1559`).
10. Broadcast failure → confirmation-failed **+ broadcast line** (`isBroadcastFailure`).
11. Chain-swap MRH + bip21 branches: after `handleChainSwap`, the triple-guard
    (`:339/:455/:1022`) still short-circuits on a swap-creation failure.
12. sendMax chain swap (`buildDummyTxsForMaxSwapAmount`) limit errors still show.
13. Happy paths: bitcoin send, liquid send, lightning swap, chain swap, payjoin,
    sendMax — all still reach `success`.
14. `state.error` removal: confirm nothing read it (done) and no analyzer break.

---

## 6. Final recommendations

1. **State shape — ship with the 6 typed slots retyped to `SendFailure`
   subtypes; collapse to a single `SendFailure? failure` as the LAST commit of
   the same PR, only after the §5 regression checklist is green.**
   Rationale: the 6 control-flow guards (`send_cubit.dart:339/455/1022/1044/1550/1559`)
   and every UI selector survive byte-for-byte through Phases 1–5, so behavior is
   provably unchanged; the final collapse is then a pure refactor verified
   against already-working code, giving the reference's single-field convergence
   without ever doing a risky big-bang rewrite. If review time is tight, the
   slots form is itself standard-compliant (sealed family in `domain/`,
   translation in `presentation/`, no raw text to UI) and the collapse can be a
   follow-up issue.

2. **`request_identifier` reuses `SendFailure`** (one sealed family per
   feature). It only ever yields "invalid payment request" →
   `SendInvalidPaymentRequestFailure`. No separate family.

3. **Scope guard:** do **not** touch `lib/core/screens/send_confirm_screen.dart`
   or `lib/core/errors/send_errors.dart`. The raw `.message` leak in
   `CommonConfirmSendErrorSection` is a **swap/core** item; record it on #1895
   for the swap and core phases, not here.

4. **Convert to `Result` only the user-visible-failure use-cases** (§4 Phase 3
   list). Leave watchers, `.wait`-tuple use-cases, and best-effort loaders on
   their current signatures; loaders switch from `emit(error:)` to `log.*`.

5. **Map the by-type catches deterministically** (preserve today's outcomes):
   `NotEnoughFundsException` → `SendInsufficientBalanceFailure`;
   `Prepare{Bitcoin,Liquid}SendException` **and** `NoSpendableUtxoException`
   → `SendBuildTransactionFailure`; `BroadcastTransactionException` /
   `GetWalletException` (in broadcast) → `SendConfirmTransactionFailure(isBroadcastFailure: true)`;
   sign failures → `SendConfirmTransactionFailure`; everything unrecognized →
   `SendUnexpectedFailure` (logged, generic UI).

6. **Tests:** one sanitization unit test per converted use-case (bad input → the
   expected `SendFailure`, asserting no raw leak — mirror
   `test/features/import_watch_only_wallet/parse_watch_only_input_usecase_test.dart`).
   Add a `request_identifier` parse test. A `SendCubit` `bloc_test` per §5 row is
   desirable but secondary; prioritize the use-case tests.

### Recommended PR sequencing (each independently green)

| PR/commit | Content | Risk |
|---|---|---|
| C1 | Phase 1 — add `send_failure.dart` + `_l10n.dart` (unused) | none (additive) |
| C2 | Phase 2 — `request_identifier` → Result + test | low (isolated) |
| C3..Cn | Phase 3 — one use-case → Result + test per commit | low each |
| Cn+1 | Phase 4 — cubit switches + log-only loaders; slots retyped | medium (guarded by §5) |
| Cn+2 | Phase 5 — UI `toTranslated`; delete `.message` helpers | low |
| Cn+3 | Phase 6 — delete inline exceptions, prune dead keys, analyze | low |
| Cn+4 *(optional)* | collapse 6 slots → single `failure` | low (post-green refactor) |

This keeps every step shippable and bisectable, which is the strongest
regression defense for a 1814-line cubit.

---

## Appendix A — foreign throw surface (condensed)

| Wrapped call (core) | Throws |
|---|---|
| `BitcoinWalletRepository.buildPsbt/signPsbt/getTxSize/getTxFeeAmount/isAddressOfWallet` | raw `Exception`, `NoSpendableUtxoException`, unwrapped BDK errors |
| `LiquidWalletRepository.buildPset/signPset/getPsetSizeAndAbsoluteFees` | raw `Exception`, LWK error strings |
| `WalletRepository.getWallet` | propagates balance/sync errors; `ElectrumFallbackException` |
| `BoltzSwapRepository.create*/getSendSwapByInvoice/updatePaidSendSwap` | Boltz error strings, raw `throw String` |
| `CreateChainSwapToExternalUsecase` | raw `throw Exception(...)` |
| `DecodeInvoiceUsecase` | `throw e.toString()` (a **String**) |
| `GetSwapLimitsUsecase` | `GetSwapLimitsException` (BullException) |
| `VerifyChainSwapAmountSendUsecase` | `SwapCreationException` (BullException) |
| `Broadcast{Bitcoin,Liquid}TransactionUsecase` | `BroadcastTransactionException` (BullException) |
| `SendWithPayjoinUsecase` | `SendPayjoinException` (BullException) |
| `GetWalletUsecase` / `GetWalletUtxosUsecase` / `GetWalletsUsecase` / `GetNetworkFeesUsecase` | `GetWalletException` / `GetUtxosUsecaseException` / `GetWalletsException`+`NoWalletsFoundException` / `GetNetworkFeesException` |
| `PaymentRequest.parse` | raw `throw String` ("Invalid payment request", etc.) |
| `select_best_wallet_usecase` | `NotEnoughFundsException` (BullException) |

> Because the surface mixes Strings, raw Exceptions, BullExceptions and SDK
> errors, the boundary catch is `catch (e, st)` (broad), logs `e`, and maps to a
> `SendFailure` variant — by type where the cubit already distinguishes, else
> `SendUnexpectedFailure`.

## Appendix B — files touched

```
NEW  lib/features/send/domain/send_failure.dart
NEW  lib/features/send/presentation/send_failure_l10n.dart
NEW  test/features/send/**                      (use-case sanitization tests)
EDIT lib/features/send/domain/usecases/*.dart   (Result return on the visible set)
EDIT lib/features/send/presentation/bloc/send_cubit.dart   (switch on Result; log loaders)
EDIT lib/features/send/presentation/bloc/send_state.dart   (retype slots; drop `error`; remove inline exceptions)
EDIT lib/features/send/request_identifier/*.dart           (Result + SendFailure)
EDIT lib/features/send/ui/screens/send_screen.dart         (toTranslated; drop helpers)
EDIT lib/features/send/send_locator.dart                   (register any extracted use-case)
EDIT localization/app_*.arb                                (prune dead keys only, if any)
KEEP lib/core/errors/send_errors.dart                      (shared core — untouched)
```
