# App settings composition

## Dependencies

- `settings` supplies the menu projection and child routes; `fees_feature`, `swap_feature`, `address_view`, `all_seed_view` and `bip85` supply typed settings destinations.
- `bull_exchange` contributes account and access routes; `backups` starts backup flows. `network` supplies diagnostics navigation and service health; `electrum` supplies the foreground storage barrier before a network change.
- The legacy wallet owner supplies public wallet discovery.
- `bull_ark` supplies its published settings UI and notification setup.
- `wallet_import` supplies typed import navigation, `send` supplies the signed-transaction reader, and `receive` supplies the Payjoin disclosure widget.
