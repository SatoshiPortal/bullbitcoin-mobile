# Bull Exchange

`BullExchangeFeature.mount` contributes the landing and support chat routes, plus the nested account settings routes. `BullExchangeNavigation`, `ExchangeSupportChatNavigation` and `ExchangeSettingsRoute` provide typed navigation. The host supplies store-aware labels and branding where applicable, and the existing authentication and exit behavior. The feature owns chat and settings view lifecycles and consumes `Exchange` directly. Sell and Pay mount at their original root routes. The host supplies wallet home navigation and the address viewer.

## Dependencies

- `bitcoin_price` supplies dashboard prices; `bull_pricer` and `fees` supply Buy pricing and fee estimates.
- `secrets` supplies the authorized payout and payin wallet inventory. `sync` issues receive addresses and provides fee-estimation addresses and unspent coins for Sell and Pay. `coins` supplies the coin selection sheet.
- Sell and Pay reuse this feature's KYC, amount and recipient flows. `spend` reviews, signs and broadcasts the approved transaction. `bull_payjoin` provides Buy receive sessions and Sell and Pay sender sessions.
- `exchange` supplies authenticated account operations, statistics, support chat, funding, withdrawals, recipient management, default payouts and AutoBuy.
