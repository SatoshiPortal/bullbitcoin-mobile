enum DlcRoute {
  dlcHome('/dlc'),
  orderbook('/dlc/orderbook'),
  myOrders('/dlc/my-orders'),
  connection('/dlc/connection'),
  placeOrder('/dlc/place-order');

  final String path;
  const DlcRoute(this.path);
}
