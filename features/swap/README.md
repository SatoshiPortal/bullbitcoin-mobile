# Swap and AutoSwap

`SwapFeature.mount` owns the transfer, confirmation, progress and settings routes. It uses the live wallet inventory from Secrets and balances, coins and admission from Sync. Spend prepares and submits funding transactions.

The public Exchange order flow in `packages/swaps` uses `databases/order_swaps.sqlite`, separate from the Boltz engine and from authenticated exchange settings. Its split-v1 import preserves request and order identities, signed funding state, wallet associations and label processing state, then checks the seven order indices before admitting the store.

## Dependencies

- `satoshifier` parses payment requests, `address_view` supplies destination input and address views, and `transactions` supplies order labels and navigation.
- `receive` supplies recipient-address selection for Ark transfers and receive values for Lightning fallback. `send` supplies Liquid consolidation status and navigation.
- `spend` prepares, signs and broadcasts Liquid funding for AutoSwap. `swaps` owns provider routing and the automatic swap policy.
