/// A transaction output reference — the minimal coin identity `(txId, vout)`
/// used by freeze persistence and spend-time exclusion.
///
/// Lives in `domain/` so repository contracts and use-cases speak it without
/// depending on any `data/` layer (the boundary rule).
typedef Outpoint = ({String txId, int vout});

/// An [Outpoint] plus its L-BTC value — for callers that need to reason
/// about *which* UTXOs to group together, not just which ones exist (e.g.
/// consolidation batching by value, so a batch is never accidentally made up
/// entirely of dust that can't even cover its own fee).
typedef OutpointAmount = ({String txId, int vout, int amountSat});
