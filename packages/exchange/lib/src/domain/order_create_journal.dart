import 'package:meta/meta.dart';

import 'entities/order.dart';

/// What an order create sent, as journaled when its outcome is unknown and
/// read back by reconcile to find the order among the recent ones. No
/// address and no secret: the type, the amount and what it is counted in.
@immutable
final class OrderCreateJournalRequest {
  final OrderType type;
  final OrderAmount amount;

  /// The fiat currency of the order when the create named one (buy, sell).
  final FiatCurrency? currency;
  final String? recipientId;

  const OrderCreateJournalRequest({
    required this.type,
    required this.amount,
    this.currency,
    this.recipientId,
  });

  Map<String, String> toRequest() => {
    'orderType': type.name,
    'amount': '${amount.amount}',
    'amountKind': switch (amount) {
      FiatAmount() => 'fiat',
      BitcoinAmount() => 'bitcoin',
    },
    'currency': ?currency?.code,
    'recipientId': ?recipientId,
  };

  /// Null when [request] is not one [toRequest] wrote.
  static OrderCreateJournalRequest? fromRequest(Map<String, String> request) {
    final type = OrderType.values
        .where((type) => type.name == request['orderType'])
        .firstOrNull;
    final value = double.tryParse(request['amount'] ?? '');
    if (type == null || value == null) return null;
    final OrderAmount amount;
    switch (request['amountKind']) {
      case 'fiat':
        amount = FiatAmount(value);
      case 'bitcoin':
        amount = BitcoinAmount(value);
      default:
        return null;
    }
    final code = request['currency'];
    final currency = FiatCurrency.values
        .where((currency) => currency.code == code)
        .firstOrNull;
    if (code != null && currency == null) return null;
    return OrderCreateJournalRequest(
      type: type,
      amount: amount,
      currency: currency,
      recipientId: request['recipientId'],
    );
  }
}
