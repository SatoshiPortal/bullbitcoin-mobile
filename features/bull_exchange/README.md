# Bull Exchange

`BullExchangeFeature.mount` contributes the landing and support chat routes, plus the nested account settings routes. `BullExchangeNavigation`, `ExchangeSupportChatNavigation` and `ExchangeSettingsRoute` provide typed navigation. The host supplies store-aware labels and branding where applicable, and the existing authentication and exit behavior. The feature owns chat and settings view lifecycles and consumes `Exchange` directly. Other exchange routes are still composed by the legacy app during extraction.
