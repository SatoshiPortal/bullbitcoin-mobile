/// Builds a `listOrderSummaries` element with sensible defaults.
///
/// Only the fields under test are overridden per case, so a regression shows up
/// as a failure on the behaviour being tested rather than as an unrelated
/// missing-field error. Pass [overrides] to replace or add raw JSON keys.
Map<String, dynamic> orderJsonFixture({
  String orderId = 'order-1',
  String orderType = 'Buy Bitcoin',
  String orderStatus = 'Completed',
  String payinStatus = 'Completed',
  String payoutStatus = 'Completed',
  Map<String, dynamic> overrides = const {},
}) => {
  'orderId': orderId,
  'orderType': orderType,
  'orderNumber': 1,
  'exchangeRateAmount': 100000,
  'exchangeRateCurrency': 'CAD',
  'payinAmount': 100,
  'payinCurrency': 'CAD',
  'payoutAmount': 0.001,
  'payoutCurrency': 'BTC',
  'orderStatus': orderStatus,
  'payinStatus': payinStatus,
  'payoutStatus': payoutStatus,
  'createdAt': '2026-07-01T12:00:00.000Z',
  'message': null,
  'payinMethod': 'Interac e-Transfer (CAD)',
  'payoutMethod': 'Bitcoin On-Chain',
  'triggerType': 'MANUAL',
  'confirmationDeadline': '2026-07-01T12:10:00.000Z',
  ...overrides,
};
