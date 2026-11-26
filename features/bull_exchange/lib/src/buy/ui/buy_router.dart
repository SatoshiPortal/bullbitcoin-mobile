/// Two routes: the buy flow, and accelerating a confirmed buy's payout by
/// order id (from the buy's done page or the transaction details). Each
/// flow's page is a function of its state, so no sub-route takes a bloc
/// from `state.extra`.
enum BuyRoute {
  buy('/buy'),
  buyAccelerate('/buy/:orderId/accelerate');

  final String path;

  const BuyRoute(this.path);
}
