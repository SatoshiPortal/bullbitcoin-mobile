/// The network a payment moves through: on-chain Bitcoin, Lightning, or
/// Liquid. Unlike `Network` in the primitives library, this identifies
/// the payment rail, not the concrete chain environment.
enum PaymentNetwork { bitcoin, lightning, liquid }
