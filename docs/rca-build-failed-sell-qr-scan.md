# RCA: "Build Failed" when scanning a Sell-order Liquid QR (works when pasting the address)

**Reported:** 2026-07-09, Slack `#wallet-bugs-issues` (Alex Pouliot)
**Flow:** Bull wallet ("Instant payments" / L-BTC) → Sell on Bull Bitcoin (Liquid deposit)
**Symptom:** Confirm screen shows the correct address and amount (0.01305000 BTC), **Network fees 0**, red **"Build Failed"**. Tapping Confirm does nothing visible. App restart does not help. In a previous occurrence, copy-pasting the bare address (instead of scanning the QR) worked.

---

## What the scanned QR is

The sell deposit QR is a BIP21 URI, same format the app itself generates for sell orders
(`lib/features/sell/presentation/bloc/sell_state.dart:237`):

```
liquidnetwork:lq1qqwzty...?amount=0.01305&assetid=<lbtc>
```

It parses into a `Bip21PaymentRequest` with `amountSat` set
(`lib/core/utils/payment_request.dart:181-247`). Parsing is fine — the user confirmed the
address is picked up correctly, and the confirm screen displays the right amount.

## Why scan and paste behave differently (the structural root cause)

The two input methods take **different code paths with different validation**:

| | Pasted bare `lq1...` address | Scanned BIP21 with `amount=` |
|---|---|---|
| Payment request type | `LiquidPaymentRequest` | `Bip21PaymentRequest` (amount embedded) |
| Amount screen shown | **Yes** — user types amount or taps **Max** | **No** — skipped entirely |
| Balance check before build | `hasBalance()` in `continueOnAmountConfirmed` (`send_cubit.dart:1124`) | **None** |
| Path | address → amount → confirm | address → **straight to confirm + build** (`send_cubit.dart:516-528`) |

In the BIP21-with-amount branch (`lib/features/send/presentation/bloc/send_cubit.dart:516-528`)
the cubit calls `handleChainSwap()` (no swap for Liquid→Liquid; it just sets
`confirmedAmountSat` and `step: confirm`, `send_cubit.dart:701-711`) and then
`createTransaction()` directly. **`hasBalance()` is never called on this path.**

## Where "Build Failed" comes from

`createTransaction()` → `PrepareLiquidSendUsecase`
(`lib/features/send/domain/usecases/prepare_liquid_send_usecase.dart:23-35`) →
`LiquidWalletRepository.buildPset` → LWK `buildLbtcTx`
(`lib/core/wallet/data/datasources/lwk_wallet_datasource.dart:391`).

Any LWK error is stringified into `PrepareLiquidSendException`, caught in
`createTransaction`'s catch block (`send_cubit.dart:1837-1845`) and stored as
`BuildTransactionException`. The UI renders only the static localized string
"Build Failed" (`lib/features/send/ui/screens/send_screen.dart:798-808`) — the real error
message is deliberately log-only (`send_state.dart:591-596`, and issue **#1924** already
tracks how unhelpful this is). Because the build never completed, `liquidAbsoluteFees`
stays null → **"Network fees 0"** on screen. Both observed symptoms match a failed
`buildLbtcTx`, not anything after it.

## Most likely underlying failure: LWK `InsufficientFunds`

The QR pins the **exact** sell pay-in amount. The wallet must fund `amount + network fee`,
and nothing on the scan path verifies it can:

- `SelectBestWalletUsecase` accepts a wallet when `balanceSat > amountSat` — **zero fee
  headroom** (`lib/features/send/domain/usecases/select_best_wallet_usecase.dart:100,109,117`).
- The BIP21 branch does no `hasBalance()` check (see table above).

So if the user is selling (close to) their **entire Instant payments balance** — the common
case for a sell — the wallet passes selection (`balance > amount`) but LWK cannot build
`amount + fee` and throws `InsufficientFunds`. This explains every data point:

- **Deterministic**: retapping Confirm just re-runs the same failing build
  (`onConfirmTransactionClicked` → `createTransaction`, `send_cubit.dart:2043-2046`), and an
  app restart changes nothing.
- **Paste works**: the manual path goes through the amount screen, where the user taps
  **Max** (→ `sendMax`/`drain=true`, which builds `balance − fee` and always succeeds) or
  types a slightly smaller amount.
- **Fees show 0, amount/address correct**: the failure happens inside the build, before any
  fee is computed.

### To confirm from the field

The exact LWK message is captured by `log.severe` in `createTransaction`'s catch
(`send_cubit.dart:1826-1845`). Ask the reporter for app logs from the failing attempt and
for their Instant payments balance at the time — expectation is
`balance − 1,305,000 sats < the ~30–60 sat Liquid network fee`. If the logs show something
other than insufficient funds, the fallback hypothesis is a stale LWK on-disk wallet DB
(`lib/core/wallet/data/datasources/lwk_facade.dart:39-64` — builds run off the persisted DB),
but the failure surviving restarts and retries over ~30 minutes makes that unlikely.

## Contributing defects (each independently worth a fix)

1. **No balance/fee validation on the scanned-BIP21 fast path** (`send_cubit.dart:516-528`).
   This is the asymmetry that makes QR scanning specifically look broken. It should run the
   same `hasBalance()` (ideally with fee headroom) and, on failure, land on the amount
   screen with a clear insufficient-balance error instead of a dead confirm screen.
2. **Underlying error discarded by the UI** (`send_screen.dart:798-808`) — user cannot tell
   "insufficient funds" from a genuine builder bug, and support cannot either. Already
   tracked as #1924; this incident is a concrete cost of it.
3. **Confirm button stays enabled after a failed build** — `disableConfirmSend` only checks
   in-flight flags (`send_state.dart:445-446`), not `buildTransactionException` /
   `unsignedPsbt == null`, so the user can keep tapping Confirm on a tx that will never
   build.
4. **Wallet selection has no fee headroom** (`select_best_wallet_usecase.dart:100`), so a
   wallet that cannot actually afford `amount + fee` is happily selected.
5. Related, product-level: a sell QR that pins the exact amount can **never** be paid by
   scanning when the order amount equals the wallet balance. Consider fee headroom guidance
   in the sell flow, or an in-app "insufficient for amount + fee — send max instead?" path.

## Not the cause (ruled out)

- BIP21/URI parsing, address casing, `assetid` handling — the address and amount reach the
  builder intact (`payment_request.dart:181-247`; amount uses `.round()`, no float
  truncation, `lib/core/utils/amount_conversions.dart:7-9`).
- Chain-swap misrouting — Liquid wallet → Liquid address never sets `isChainSwap`
  (`send_state.dart:484-486`); screenshot shows a direct Liquid send.
- Fee-list mixup — `selectedFee` correctly uses the Liquid fee list for Liquid wallets
  (`send_state.dart:464-482`).
