import 'package:bb_mobile/core/exchange/data/models/order_model.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'order.freezed.dart';

enum FiatCurrency { cad, eur, mxn }

enum OrderType { buy, sell }

extension OrderTypeExtension on OrderType {
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

enum Network { lightning, bitcoin, liquid }

extension FiatCurrencyExtension on FiatCurrency {
  String get value {
    switch (this) {
      case FiatCurrency.cad:
        return 'CAD';
      case FiatCurrency.eur:
        return 'EUR';
      case FiatCurrency.mxn:
        return 'MXN';
    }
  }

  static FiatCurrency fromValue(String value) {
    switch (value.toUpperCase()) {
      case 'CAD':
        return FiatCurrency.cad;
      case 'EUR':
        return FiatCurrency.eur;
      case 'MXN':
        return FiatCurrency.mxn;
      default:
        throw Exception('Unknown FiatCurrency: $value');
    }
  }
}

extension NetworkExtension on Network {
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

  factory Order.fromModel(OrderModel model) {
    Network network;
    if (model.payoutMethod.toLowerCase().contains('lightning')) {
      network = Network.lightning;
    } else if (model.payoutMethod.toLowerCase().contains('liquid')) {
      network = Network.liquid;
    } else {
      network = Network.bitcoin;
    }

    final params = {
      'orderId': model.orderId,
      'orderSubtype': model.orderSubtype,
      'orderNumber': model.orderNumber,
      'exchangeRateAmount': model.exchangeRateAmount,
      'exchangeRateCurrency': model.exchangeRateCurrency,
      'indexRateAmount': model.indexRateAmount,
      'indexRateCurrency': model.indexRateCurrency,
      'payinAmount': model.payinAmount,
      'payinCurrency': FiatCurrencyExtension.fromValue(model.payinCurrency),
      'payoutAmount': model.payoutAmount,
      'payoutCurrency': model.payoutCurrency,
      'orderStatus': model.orderStatus,
      'payinStatus': model.payinStatus,
      'payoutStatus': model.payoutStatus,
      'scheduledPayoutTime': model.scheduledPayoutTime,
      'createdAt': DateTime.parse(model.createdAt),
      'completedAt':
          model.completedAt != null ? DateTime.parse(model.completedAt!) : null,
      'message': model.message,
      'sentAt': model.sentAt != null ? DateTime.parse(model.sentAt!) : null,
      'payinMethod': model.payinMethod,
      'payoutMethod': model.payoutMethod,
      'triggerType': model.triggerType,
      'confirmationDeadline': DateTime.parse(model.confirmationDeadline),
      'unbatchedBuyOnchainFees': model.unbatchedBuyOnchainFees,
      'bitcoinTransactionId': model.bitcoinTransactionId,
      'lnUrl': model.lnUrl,
      'lightningVoucherExpiresAt':
          model.lightningVoucherExpiresAt != null
              ? DateTime.parse(model.lightningVoucherExpiresAt!)
              : null,
      'isPPBitcoinOutUpdatable': model.isPPBitcoinOutUpdatable,
      'payinAmountChanged': model.payinAmountChanged,
      'network': network,
    };

    return model.orderType.toLowerCase() == 'buy'
        ? Order.buy(
          orderId: params['orderId'] as String,
          orderSubtype: params['orderSubtype'] as String,
          orderNumber: params['orderNumber'] as int,
          exchangeRateAmount: params['exchangeRateAmount'] as double,
          exchangeRateCurrency: params['exchangeRateCurrency'] as String,
          indexRateAmount: params['indexRateAmount'] as double,
          indexRateCurrency: params['indexRateCurrency'] as String,
          payinAmount: params['payinAmount'] as double,
          payinCurrency: params['payinCurrency'] as FiatCurrency,
          payoutAmount: params['payoutAmount'] as double,
          payoutCurrency: params['payoutCurrency'] as String,
          orderStatus: params['orderStatus'] as String,
          payinStatus: params['payinStatus'] as String,
          payoutStatus: params['payoutStatus'] as String,
          scheduledPayoutTime: params['scheduledPayoutTime'] as String?,
          createdAt: params['createdAt'] as DateTime,
          completedAt: params['completedAt'] as DateTime?,
          message: params['message'] as Map<String, dynamic>?,
          sentAt: params['sentAt'] as DateTime?,
          payinMethod: params['payinMethod'] as String,
          payoutMethod: params['payoutMethod'] as String,
          triggerType: params['triggerType'] as String,
          confirmationDeadline: params['confirmationDeadline'] as DateTime,
          unbatchedBuyOnchainFees: params['unbatchedBuyOnchainFees'],
          bitcoinTransactionId: params['bitcoinTransactionId'] as String?,
          lnUrl: params['lnUrl'] as String?,
          lightningVoucherExpiresAt:
              params['lightningVoucherExpiresAt'] as DateTime?,
          isPPBitcoinOutUpdatable: params['isPPBitcoinOutUpdatable'] as bool,
          payinAmountChanged: params['payinAmountChanged'],
          network: params['network'] as Network,
        )
        : Order.sell(
          orderId: params['orderId'] as String,
          orderSubtype: params['orderSubtype'] as String,
          orderNumber: params['orderNumber'] as int,
          exchangeRateAmount: params['exchangeRateAmount'] as double,
          exchangeRateCurrency: params['exchangeRateCurrency'] as String,
          indexRateAmount: params['indexRateAmount'] as double,
          indexRateCurrency: params['indexRateCurrency'] as String,
          payinAmount: params['payinAmount'] as double,
          payinCurrency: params['payinCurrency'] as FiatCurrency,
          payoutAmount: params['payoutAmount'] as double,
          payoutCurrency: params['payoutCurrency'] as String,
          orderStatus: params['orderStatus'] as String,
          payinStatus: params['payinStatus'] as String,
          payoutStatus: params['payoutStatus'] as String,
          scheduledPayoutTime: params['scheduledPayoutTime'] as String?,
          createdAt: params['createdAt'] as DateTime,
          completedAt: params['completedAt'] as DateTime?,
          message: params['message'] as Map<String, dynamic>?,
          sentAt: params['sentAt'] as DateTime?,
          payinMethod: params['payinMethod'] as String,
          payoutMethod: params['payoutMethod'] as String,
          triggerType: params['triggerType'] as String,
          confirmationDeadline: params['confirmationDeadline'] as DateTime,
          unbatchedBuyOnchainFees: params['unbatchedBuyOnchainFees'],
          bitcoinTransactionId: params['bitcoinTransactionId'] as String?,
          lnUrl: params['lnUrl'] as String?,
          lightningVoucherExpiresAt:
              params['lightningVoucherExpiresAt'] as DateTime?,
          isPPBitcoinOutUpdatable: params['isPPBitcoinOutUpdatable'] as bool,
          payinAmountChanged: params['payinAmountChanged'],
          network: params['network'] as Network,
        );
  }

  bool isCompleted() => orderStatus.toLowerCase() == 'complete';
  bool isProcessing() => orderStatus.toLowerCase() == 'processing';
  bool isCancelled() => orderStatus.toLowerCase() == 'cancelled';
  bool isExpired() => orderStatus.toLowerCase() == 'expired';
  bool isPending() => orderStatus.toLowerCase() == 'pending';
}
