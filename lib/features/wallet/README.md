# Legacy wallet composition

## Dependencies

- `scanning` supplies public QR scanning; `signers` supplies signer device properties. `satoshifier` parses payment requests and public extended keys.
- `receive` supplies transfer-address selection; `address_view` publishes address display and `transactions` supplies wallet detail history widgets. `backups` starts backup flows.
- `silent` supplies account snapshots and sync; the wallet supplies an exact-network fingerprint through composition. `swap_feature` supplies the mounted activity capability and the scheduling port implemented by the wallet.
- `bull_ark` supplies published foreground setup and wallet UI; `ark` supplies the funding guard used by the Payjoin signing adapter.
- `wallet_import` supplies public import inputs and failures, and `send` supplies the consolidation banner.
