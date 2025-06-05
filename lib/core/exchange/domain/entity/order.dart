import 'package:freezed_annotation/freezed_annotation.dart';

part 'order.freezed.dart';

enum FiatCurrency {
  cad('CAD'),
  eur('EUR'),
  mxn('MXN');

  const FiatCurrency(this.code);
  final String code;

  static FiatCurrency fromCode(String code) {
    switch (code.toUpperCase()) {
      case 'CAD':
        return FiatCurrency.cad;
      case 'EUR':
        return FiatCurrency.eur;
      case 'MXN':
        return FiatCurrency.mxn;
      default:
        throw Exception('Unknown FiatCurrency: $code');
    }
  }
}

enum OrderType {
  buy,
  sell;

  String get value {
    switch (this) {
      case OrderType.buy:
        return 'buy';
      case OrderType.sell:
        return 'sell';
    }
  }

  static OrderType fromValue(String value) {
    switch (value.toLowerCase()) {
      case 'buy':
        return OrderType.buy;
      case 'sell':
        return OrderType.sell;
      default:
        throw Exception('Unknown OrderType: $value');
    }
  }
}

enum Network {
  lightning,
  bitcoin,
  liquid;

  String get value {
    switch (this) {
      case Network.lightning:
        return 'lightning';
      case Network.bitcoin:
        return 'bitcoin';
      case Network.liquid:
        return 'liquid';
    }
  }

  static Network fromValue(String value) {
    switch (value.toLowerCase()) {
      case 'lightning':
        return Network.lightning;
      case 'bitcoin':
        return Network.bitcoin;
      case 'liquid':
        return Network.liquid;
      default:
        throw Exception('Unknown Network: $value');
    }
  }
}

sealed class OrderAmount {
  final double amount;

  const OrderAmount(this.amount);

  bool get isFiat => this is FiatAmount;
  bool get isBitcoin => this is BitcoinAmount;
}

class FiatAmount extends OrderAmount {
  const FiatAmount(super.amount);
}

class BitcoinAmount extends OrderAmount {
  const BitcoinAmount(super.amount);
}

@freezed
sealed class Order with _$Order {
  const Order._();

  const factory Order.buy({
    required String orderId,
    required String orderSubtype,
    required int orderNumber,
    required double exchangeRateAmount,
    required String exchangeRateCurrency,
    required double indexRateAmount,
    required String indexRateCurrency,
    required double payinAmount,
    required FiatCurrency payinCurrency,
    required double payoutAmount,
    required String payoutCurrency,
    required String orderStatus,
    required String payinStatus,
    required String payoutStatus,
    String? scheduledPayoutTime,
    required DateTime createdAt,
    DateTime? completedAt,
    Map<String, dynamic>? message,
    DateTime? sentAt,
    required String payinMethod,
    required String payoutMethod,
    required String triggerType,
    required DateTime confirmationDeadline,
    dynamic unbatchedBuyOnchainFees,
    String? bitcoinTransactionId,
    String? lnUrl,
    DateTime? lightningVoucherExpiresAt,
    required bool isPPBitcoinOutUpdatable,
    dynamic payinAmountChanged,
    required Network network,
  }) = BuyOrder;

  const factory Order.sell({
    required String orderId,
    required String orderSubtype,
    required int orderNumber,
    required double exchangeRateAmount,
    required String exchangeRateCurrency,
    required double indexRateAmount,
    required String indexRateCurrency,
    required double payinAmount,
    required FiatCurrency payinCurrency,
    required double payoutAmount,
    required String payoutCurrency,
    required String orderStatus,
    required String payinStatus,
    required String payoutStatus,
    String? scheduledPayoutTime,
    required DateTime createdAt,
    DateTime? completedAt,
    Map<String, dynamic>? message,
    DateTime? sentAt,
    required String payinMethod,
    required String payoutMethod,
    required String triggerType,
    required DateTime confirmationDeadline,
    dynamic unbatchedBuyOnchainFees,
    String? bitcoinTransactionId,
    String? lnUrl,
    DateTime? lightningVoucherExpiresAt,
    required bool isPPBitcoinOutUpdatable,
    dynamic payinAmountChanged,
    required Network network,
  }) = SellOrder;

  bool get isPayinCompleted => payinStatus.toLowerCase() == 'completed';
  bool get isPayoutCompleted => payoutStatus.toLowerCase() == 'completed';

  // TODO: Check if these values are correct and if no other statuses are need to
  // be checked instead of these ones.
  bool isCompleted() => orderStatus.toLowerCase() == 'complete';
  bool isProcessing() => orderStatus.toLowerCase() == 'processing';
  bool isCancelled() => orderStatus.toLowerCase() == 'cancelled';
  bool isExpired() => orderStatus.toLowerCase() == 'expired';
  bool isPending() => orderStatus.toLowerCase() == 'pending';
}
