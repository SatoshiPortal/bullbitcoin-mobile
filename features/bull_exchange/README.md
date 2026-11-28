# Bull Exchange

`BullExchangeFeature.mount` contributes the landing and support chat routes, plus the nested account settings routes. `BullExchangeNavigation`, `ExchangeSupportChatNavigation` and `ExchangeSettingsRoute` provide typed navigation. The feature owns the landing copy, sign-in navigation and the chat and settings view lifecycles. Sell, Pay and Limit Order creation mount at their original root routes. The host opens the capability with `BullExchangeServices.open` from `setup.dart`, which owns the Exchange endpoints, credentials, access lifecycle and iOS trading policy, then mounts the feature with that capability, branding, app navigation and the wallet services Buy, DCA, Sell and Pay need. The feature builds its authentication, dashboard, Auto Buy, withdrawal, KYC and support chat hosts itself, and translates `ExchangeFailure` with `ExchangeFailureL10n`. `ExchangeAccessBuilder` rebuilds account entry points as access changes.

## Dependencies

- `address_view` supplies the shared destination parser, scanner, field and address viewer. `transactions` opens order details and history and labels completed orders.
- `bitcoin_price` supplies dashboard prices; `bull_pricer` and `fees` supply Buy pricing and fee estimates.
- `secrets` supplies the authorized payout and payin wallet inventory. `sync` issues receive addresses and provides fee-estimation addresses and unspent coins for Sell and Pay. `coins` supplies the coin selection sheet.
- Sell and Pay reuse this feature's KYC, amount and recipient flows. `spend` reviews, signs and broadcasts the approved transaction. `bull_payjoin` provides Buy receive sessions and Sell and Pay sender sessions.
- `exchange` supplies authenticated account operations, statistics, support chat, funding, withdrawals, recipient management, default payouts and AutoBuy.
- Limit Orders use `secrets` to list authorized wallets and `sync` to read the latest receive address without issuing a new one. `satoshifier` parses manually entered Lightning addresses.

## Witnessed Pay and Sell choices

The existing pickers are not switched to Overview. A future picker can pass an explicit `PayinFromAppWallet.witnessed` with the complete key, incarnation, raw nullable label and a synchronous live-receipt check. Pay and Sell bind that choice to their own attempt on event acceptance. Witnesses are not persisted and do not authorize spend.

The current BBX, preview, Spend and Payjoin adapters cannot carry a foreground attempt through their owner waits to the actual effect. Witnessed choices therefore fail closed on these adapters, including manual Payjoin retry by session ID; they never downgrade to the old ID-only path. The external rails and already-submitted result, journal and reconciliation paths are unchanged. An exact owner must check `PayinWalletAttempt` immediately before its effect, not merely wrap the existing asynchronous call. The UI switch remains blocked until these owners can honor that contract.
