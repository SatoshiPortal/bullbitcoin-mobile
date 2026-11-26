# Coins

`CoinsFeature.mount` owns `/coins`, its presentation state and its localization. It consumes the existing wallet identity and sync signals from the host, reads coins and freezes through Sync and enriches coins with Labels.

`package:coins/coins.dart` publishes typed reads for wallet coins, their summary and global frozen outpoints, plus typed navigation and the reusable `CoinSelectionSheet`. The sheet returns selected outpoints; it has no signing authority. The spend path checks input eligibility again independently of this UI.

## Dependencies

- The host supplies the wallet revision stream that refreshes the coin projection; `address_view` renders addresses for coin selection.
