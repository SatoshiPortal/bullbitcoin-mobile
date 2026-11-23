# Boltz swaps

The Boltz owner uses `databases/swaps.sqlite` and `databases/swaps_regtest.sqlite`, with independent keys and lifecycle receipts. The production store also owns the automatic-swap thresholds and scheduling preferences. This does not move the engine's existing scoped swap-key handles out of Secrets.

Legacy standalone rows retain their current status and pending signed lockup state. The app's historical swap identities are checked before admitting the encrypted store; an ambiguous earlier import fails closed. The legacy files and their journals remain intact.
