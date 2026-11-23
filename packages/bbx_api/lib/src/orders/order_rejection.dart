import 'package:bbx_api/src/bbx_failure.dart';
import 'package:bbx_api/src/rpc_error.dart';

/// Reads the JSON-RPC [error] of an order creation.
///
/// A single refused payment option carries `data.reason.limit`; when every
/// option was refused, `data.reasons` holds one reason per option. `reasons`
/// can be empty or hold no limit (group access denied, amount not positive),
/// and the aggregate's legacy `data.details` is never read. Limits with mixed
/// bounds or currencies, or a bound that is neither a minimum nor a maximum,
/// give a plain [BbxRpcFailure].
BbxFailure orderRejection(Object error) {
  final rpc = bbxRpcFailure(error);
  final data = error is Map ? error['data'] : null;
  final dataMap = data is Map ? data : const <dynamic, dynamic>{};

  final apiError = dataMap['apiError'];
  if (apiError is Map && apiError['code'] == 'ERR_ORD_CSRCP400') {
    return BbxConfidentialSepaInactiveFailure(
      code: rpc.code,
      apiCode: rpc.apiCode,
    );
  }

  final limits = <_Limit>[];
  final reasons = dataMap['reasons'];
  if (reasons is List) {
    for (final reason in reasons) {
      final limit = _Limit.tryParse(reason is Map ? reason['limit'] : null);
      if (limit != null) limits.add(limit);
    }
  }
  final reason = dataMap['reason'];
  final singleLimit = _Limit.tryParse(reason is Map ? reason['limit'] : null);
  if (singleLimit != null) limits.add(singleLimit);

  final operators = limits.map((l) => l.operator).toSet();
  final currencies = limits.map((l) => l.currency).toSet();
  if (operators.length == 1 && currencies.length == 1) {
    switch (operators.single) {
      case 'GREATER_THAN_OR_EQUAL':
        final min = limits.reduce((a, b) => a.amount <= b.amount ? a : b);
        return BbxOrderLimitFailure(
          bound: BbxOrderLimitBound.minimum,
          amount: min.amount,
          currency: min.currency,
          code: rpc.code,
          apiCode: rpc.apiCode,
        );
      case 'LESS_THAN_OR_EQUAL':
        final max = limits.reduce((a, b) => a.amount >= b.amount ? a : b);
        return BbxOrderLimitFailure(
          bound: BbxOrderLimitBound.maximum,
          amount: max.amount,
          currency: max.currency,
          code: rpc.code,
          apiCode: rpc.apiCode,
        );
    }
  }
  return rpc;
}

class _Limit {
  final double amount;
  final String currency;
  final String operator;

  const _Limit(this.amount, this.currency, this.operator);

  static _Limit? tryParse(Object? json) {
    if (json is! Map) return null;
    final amount = switch (json['amount']) {
      final num n => n.toDouble(),
      final String s => double.tryParse(s),
      _ => null,
    };
    final currency = json['currencyCode'];
    final operator = json['conditionalOperator'];
    if (amount == null || currency is! String || operator is! String) {
      return null;
    }
    return _Limit(amount, currency, operator);
  }
}
