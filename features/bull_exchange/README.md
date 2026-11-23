# Bull Exchange

`BullExchangeFeature.mount` contributes the landing and support chat routes. `BullExchangeNavigation` and `ExchangeSupportChatNavigation` provide typed navigation. The host supplies the landing's store-aware localization and branding, and the existing authentication and exit behavior. Chat owns its localized copy, attachment handling and view lifecycle and consumes `Exchange` directly. Other exchange routes are still composed by the legacy app during extraction.
