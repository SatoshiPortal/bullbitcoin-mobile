# Coins

`package:coins/coins.dart` publishes `CoinSelectionSheet`. The caller opens the sheet and supplies display-ready eligible coins, localized copy, amount display preferences and an address renderer. The sheet returns selected outpoints; it has no wallet catalogue, routes of its own or signing authority. The spend path checks input eligibility again independently of this UI.
