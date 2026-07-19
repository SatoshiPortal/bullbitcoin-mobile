enum GetPaidDashboardRoute {
  getPaidHome('/get-paid'),
  getPaidTransactions('transactions'),
  getPaidTransactionDetail('detail');

  final String path;

  const GetPaidDashboardRoute(this.path);
}
