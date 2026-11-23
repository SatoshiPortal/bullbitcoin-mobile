# Send journeys

`SendFeature.mount` contributes the signed-transaction reader, Liquid consolidation and fee replacement routes. The root app supplies wallet home navigation and the wallet balance shown in consolidation review. Spend owns the transaction operations; this feature owns the routes, screen state and translations.

## Dependencies

- `satoshifier` assembles BBQR from signed-transaction scans. `scanning` provides QR and NFC acquisition, and `address_view` renders addresses for review.
- `spend` owns transaction preparation and broadcast. `sync` publishes wallet reads and chain operations, and `electrum` selects the connection for chain access.
