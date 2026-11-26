/// The network a payment moves through: on-chain Bitcoin, Lightning, or
/// Liquid. Shared across features (e.g. `swap`, `dca`) that need to name a
/// network without depending on each other's internal types.
enum PaymentNetwork { bitcoin, lightning, liquid }
