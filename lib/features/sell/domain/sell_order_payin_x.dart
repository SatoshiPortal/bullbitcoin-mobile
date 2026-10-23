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

  /// The payin (deposit) address for the order's own payin network, so a Liquid
  /// payin never surfaces the Bitcoin address (or vice-versa). Lightning payins
  /// carry no address — use [sellLightningInvoice].
  String? get sellPayinAddress {
    final bitcoinAddress = switch (this) {
      SellOrder(:final bitcoinAddress) ||
      FiatPaymentOrder(:final bitcoinAddress) => bitcoinAddress,
      _ => null,
    };
    final liquidAddress = switch (this) {
      SellOrder(:final liquidAddress) ||
      FiatPaymentOrder(:final liquidAddress) => liquidAddress,
      _ => null,
    };
    return switch (payinMethod) {
      OrderPaymentMethod.bitcoin => bitcoinAddress,
      OrderPaymentMethod.liquid => liquidAddress,
      _ => null,
    };
  }
}
