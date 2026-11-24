# Exchange payin binding

`exchange_payin_binding.dart` gives Sell and Pay the wallet cards, the wallet-home route and the app assets. It remains in the app while wallet cards and the wallet-home route live in `lib/features/wallet`; `bull_exchange` cannot import the app that mounts it. Everything else of the Exchange feature is in `features/bull_exchange` and `packages/exchange`.
