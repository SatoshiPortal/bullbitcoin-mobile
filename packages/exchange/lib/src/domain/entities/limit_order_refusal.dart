import '../exchange_call_result.dart';

/// Why the exchange refused a limit-order create, read from its code.
enum LimitOrderRefusal {
  /// The account already has the maximum of active limit orders.
  maximumActive,

  /// The payout address is not one the exchange accepts.
  invalidAddress,

  /// Any other refusal: nothing was created.
  other,
}

LimitOrderRefusal limitOrderRefusalOf(ExchangeRefusal refusal) =>
    switch (refusal.apiCode) {
      'ERR_ORDTRG_LOMAX429' => LimitOrderRefusal.maximumActive,
      'ERR_ORDTRG_ADDR400' => LimitOrderRefusal.invalidAddress,
      _ => LimitOrderRefusal.other,
    };
