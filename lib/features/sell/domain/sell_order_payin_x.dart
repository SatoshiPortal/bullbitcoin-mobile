import 'package:bb_mobile/core/exchange/domain/entity/order.dart';

extension SellOrderPayinX on Order {
  double? get sellExchangeRateAmount => switch (this) {
    SellOrder(:final exchangeRateAmount) ||
    FiatPaymentOrder(:final exchangeRateAmount) => exchangeRateAmount,
    _ => null,
  };

  String? get sellExchangeRateCurrency => switch (this) {
    SellOrder(:final exchangeRateCurrency) ||
    FiatPaymentOrder(:final exchangeRateCurrency) => exchangeRateCurrency,
    _ => null,
  };

  String? get sellLightningInvoice => switch (this) {
    SellOrder(:final lightningInvoice) ||
    FiatPaymentOrder(:final lightningInvoice) => lightningInvoice,
    _ => null,
  };
}
