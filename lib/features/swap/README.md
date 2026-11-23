# Public order swaps

The order flow uses `databases/order_swaps.sqlite`, separate from the Boltz engine and from authenticated exchange settings. Its split-v1 import preserves request and order identities, signed funding state, wallet associations and label processing state, then checks the seven order indices before admitting the store.
