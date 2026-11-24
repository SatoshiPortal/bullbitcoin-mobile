# Send journeys

`SendFeature.mount` contributes the payment, signed transaction reader, Liquid consolidation and fee replacement routes. Callers open a payment with `SendNavigation` and a typed account key. Send uses Secrets for account identity, Sync for balances and revisions, Signers for devices, and Coins for coin reads and selection. Spend owns wallet-bound preparation, signing and broadcast. Send owns payment orchestration, review and translations.

The app composes navigation to wallet home and coin management. Consolidation still receives the balance displayed by the legacy wallet-detail route. The app supplies the existing order review card to avoid a dependency cycle with Swap, which opens Send's consolidation route.

## Dependencies

- `satoshifier` parses payment requests and assembles BBQR from signed-transaction scans. `scanning` provides QR and NFC acquisition, and `address_view` renders addresses for review.
- `rust_bindings` reads a Lightning recipient's LNURL-pay bounds before Send asks `satoshifier` for an invoice of the chosen amount.
- `secrets` resolves account identity, `sync` publishes balances, revisions and chain operations, and `electrum` selects the connection for chain access.
- `spend` owns wallet-bound preparation, signing and broadcast. `signers` drives hardware devices, `bull_payjoin` runs Payjoin sessions, `swaps` and `bull_ark` provide swap and Ark payments, and `silent` provides Silent Payments.
- `coins` supplies coin reads and the selection sheet, and `fees` with `fees_feature` provide fee estimates and editing.
- `Send.open` reads the active network and quote currency from `preferences` and obtains fiat prices through `bull_pricer`.
