# Boltz swaps

The Boltz owner uses `databases/swaps.sqlite` and `databases/swaps_regtest.sqlite`, with independent keys and lifecycle receipts. The production store also owns the automatic-swap thresholds and scheduling preferences. This does not move the engine's existing scoped swap-key handles out of Secrets.

Legacy standalone rows retain their current status and pending signed lockup state. The app's historical swap identities are checked before admitting the encrypted store; an ambiguous earlier import fails closed. The legacy files and their journals remain intact.

The app opens the engine with `Swaps.open` after both databases have been admitted. One set of `store`, `resolver` and `boltz` handles follows provider and environment changes; `followEnvironment` does not start polling by itself. The package reads and updates the Boltz server and autoswap settings, with a typed failure for unsupported environments. Before the app wallet catalogue is retired, composition supplies the wallet choice and wallet-relative address and history projections.

## Dependencies

Composition supplies fresh receive addresses for claim and refund destinations, and wallet-relative transaction evidence for swap reconciliation. These callbacks avoid importing either feature owner from the package.
