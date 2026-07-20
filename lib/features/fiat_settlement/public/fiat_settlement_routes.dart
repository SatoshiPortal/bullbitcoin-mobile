enum FiatSettlementRoute {
  fiatSettlementEditor('/fiat-settlement/:product');

  const FiatSettlementRoute(this.path);

  final String path;
}
