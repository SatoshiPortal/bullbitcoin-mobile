# Send journeys

`SendFeature.mount` contributes the payment, signed transaction reader, Liquid consolidation and fee replacement routes. Callers open a payment with `SendNavigation` and a typed account key. Send uses Secrets for account identity, Sync for balances and revisions, Signers for devices, and Coins for coin reads and selection. Spend owns wallet-bound preparation, signing and broadcast. Send owns payment orchestration, review and translations.

The app composes navigation to wallet home and coin management. Consolidation still receives the balance displayed by the legacy wallet-detail route. The app supplies the existing order review card to avoid a dependency cycle with Swap, which opens Send's consolidation route.
