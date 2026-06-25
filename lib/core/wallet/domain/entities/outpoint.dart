/// A transaction output reference — the minimal coin identity `(txId, vout)`
/// used by freeze persistence and spend-time exclusion.
///
/// Lives in `domain/` so repository contracts and use-cases speak it without
/// depending on any `data/` layer (the boundary rule).
typedef Outpoint = ({String txId, int vout});
