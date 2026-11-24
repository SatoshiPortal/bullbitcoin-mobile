# Bull Exchange

`BullExchangeFeature.mount` contributes the landing and support chat routes, plus the nested account settings routes. `BullExchangeNavigation`, `ExchangeSupportChatNavigation` and `ExchangeSettingsRoute` provide typed navigation. The feature owns the landing copy, sign-in navigation and the chat and settings view lifecycles. The host supplies the store vocabulary policy, branding and exit destination. Sell, Pay and Limit Order creation mount at their original root routes. The host supplies wallet home navigation, the address viewer and the shared destination input.

## Dependencies

- `bitcoin_price` supplies dashboard prices; `bull_pricer` and `fees` supply Buy pricing and fee estimates.
- `secrets` supplies the authorized payout and payin wallet inventory. `sync` issues receive addresses and provides fee-estimation addresses and unspent coins for Sell and Pay. `coins` supplies the coin selection sheet.
- Sell and Pay reuse this feature's KYC, amount and recipient flows. `spend` reviews, signs and broadcasts the approved transaction. `bull_payjoin` provides Buy receive sessions and Sell and Pay sender sessions.
- `exchange` supplies authenticated account operations, statistics, support chat, funding, withdrawals, recipient management, default payouts and AutoBuy.
- Limit Orders use `secrets` to list authorized wallets and `sync` to read the latest receive address without issuing a new one. `satoshifier` parses manually entered Lightning addresses.
