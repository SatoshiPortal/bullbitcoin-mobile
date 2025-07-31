import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'order.freezed.dart';

enum FiatCurrency {
  usd('USD', decimals: 2, symbol: '\$'),
  cad('CAD', decimals: 2, symbol: '\$'),
  crc('CRC', decimals: 2, symbol: '₡'),
  eur('EUR', decimals: 2, symbol: '€'),
  mxn('MXN', decimals: 2, symbol: '\$');

  const FiatCurrency(this.code, {required this.decimals, required this.symbol});
  final String code;
  final int decimals;
  final String symbol;

  static FiatCurrency fromCode(String code) {
    switch (code.toUpperCase()) {
      case 'USD':
        return FiatCurrency.usd;
      case 'CAD':
        return FiatCurrency.cad;
      case 'CRC':
        return FiatCurrency.crc;
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
  buy('Buy Bitcoin'),
  sell('Sell Bitcoin'),
  fiatPayment('Fiat Payment'),
  funding('Funding'),
  withdraw('Withdraw'),
  reward('Reward'),
  refund('Refund'),
  balanceAdjustment('Balance Adjustment');

  final String value;
  const OrderType(this.value);

  static OrderType fromValue(String value) {
    return OrderType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw Exception('Unknown OrderType: $value'),
    );
  }
}

enum OrderBitcoinNetwork {
  bitcoin('bitcoin'),
  liquid('liquid'),
  lightning('lightning');

  final String value;
  const OrderBitcoinNetwork(this.value);

  @override
  String toString() => value;

  static OrderBitcoinNetwork fromValue(String value) {
    return OrderBitcoinNetwork.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw Exception('Unknown OrderBitcoinNetwork: $value'),
    );
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

enum OrderStatus {
  canceled('Canceled'),
  expired('Payment deadline expired'),
  inProgress('In progress'),
  awaitingConfirmation('Awaiting confirmation'),
  completed('Completed'),
  rejected('Rejected');

  final String value;
  const OrderStatus(this.value);

  static OrderStatus fromValue(String value) {
    return OrderStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw Exception('Unknown OrderStatus: $value'),
    );
  }
}

enum OrderPayinStatus {
  notStarted('Not started'),
  awaitingPayment('Awaiting payment'),
  inProgress('In progress'),
  underReview('Under review'),
  awaitingConfirmation('Awaiting confirmation'),
  completed('Completed'),
  rejected('Rejected');

  final String value;
  const OrderPayinStatus(this.value);

  static OrderPayinStatus fromValue(String value) {
    return OrderPayinStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw Exception('Unknown OrderPayinStatus: $value'),
    );
  }
}

enum OrderPayoutStatus {
  notStarted('Not started'),
  inProgress('In progress'),
  scheduled('Scheduled'),
  awaitingClaim('Awaiting claim'),
  completed('Completed'),
  canceled('Canceled');

  final String value;
  const OrderPayoutStatus(this.value);

  static OrderPayoutStatus fromValue(String value) {
    return OrderPayoutStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw Exception('Unknown OrderPayoutStatus: $value'),
    );
  }
}

enum OrderPaymentMethod {
  eTransfer('E-Transfer'),
  billPayment('Bill payment'),
  bankTransfer('Bank transfer'),
  loadhub('Loadhub'),
  sepa('SEPA'),
  iban('IBAN'),
  sinpe('SINPE'),
  cadBalance('CAD Balance'),
  eurBalance('EUR Balance'),
  mxnBalance('MXN Balance'),
  crcBalance('CRC Balance'),
  usdBalance('USD Balance'),
  bitcoin('Bitcoin'),
  liquid('Liquid'),
  lnAddress('Lightning address'),
  lnInvoice('Lightning invoice'),
  lnUrl('Lightning (LNURL)'),
  referralCad('Referral CAD'),
  referralEur('Referral EUR'),
  referralMxn('Referral MXN'),
  referralUsd('Referral USD'),
  referralCrc('Referral CRC'),
  spei('SPEI'),
  thinAir('Thin Air'),
  refundCrc('Refund CRC'),
  refundUsd('Refund USD');

  final String value;
  const OrderPaymentMethod(this.value);

  static OrderPaymentMethod fromValue(String value) {
    return OrderPaymentMethod.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw Exception('Unknown OrderPaymentMethod: $value'),
    );
  }
}

class OrderMessage {
  final String code;
  final String message;

  OrderMessage({required this.code, required this.message});
}

class PayinAmountChanged {
  final double requestedAmount;
  final double receivedAmount;

  PayinAmountChanged({
    required this.requestedAmount,
    required this.receivedAmount,
  });
}

@freezed
sealed class Order with _$Order {
  const Order._();

  const factory Order.buy({
    required String orderId,
    required OrderType orderType,
    String? orderSubtype,
    required OrderMessage message,
    required int orderNumber,
    required double payinAmount,
    required String payinCurrency,
    required double payoutAmount,
    required String payoutCurrency,
    double? exchangeRateAmount,
    String? exchangeRateCurrency,
    required OrderPaymentMethod payinMethod,
    required OrderPaymentMethod payoutMethod,
    required OrderStatus orderStatus,
    required OrderPayinStatus payinStatus,
    required OrderPayoutStatus payoutStatus,
    required DateTime confirmationDeadline,
    required DateTime createdAt,
    DateTime? scheduledPayoutTime,
    String? lightningInvoice,
    String? bitcoinAddress,
    String? bitcoinTransactionId,
    String? liquidAddress,
    String? liquidTransactionId,
    String? lightningAddress,
    String? lnUrl,
    String? beneficiaryName,
    String? beneficiaryLabel,
    String? beneficiaryAccountNumber,
    DateTime? completedAt,
    DateTime? sentAt,
    bool? isPPBitcoinOutUpdatable,
    PayinAmountChanged? payinAmountChanged,
    double? indexRateAmount,
    String? indexRateCurrency,
    DateTime? lightningVoucherExpiresAt,
    double? unbatchedBuyOnchainFees,
    required bool isTestnet,
  }) = BuyOrder;

  const factory Order.sell({
    required String orderId,
    required OrderType orderType,
    String? orderSubtype,
    required OrderMessage message,
    required int orderNumber,
    required double payinAmount,
    required String payinCurrency,
    required double payoutAmount,
    required String payoutCurrency,
    double? exchangeRateAmount,
    String? exchangeRateCurrency,
    required OrderPaymentMethod payinMethod,
    required OrderPaymentMethod payoutMethod,
    required OrderStatus orderStatus,
    required OrderPayinStatus payinStatus,
    required OrderPayoutStatus payoutStatus,
    required DateTime confirmationDeadline,
    required DateTime createdAt,
    DateTime? scheduledPayoutTime,
    String? lightningInvoice,
    String? bitcoinAddress,
    String? bitcoinTransactionId,
    String? liquidAddress,
    String? liquidTransactionId,
    String? lightningAddress,
    String? lnUrl,
    String? beneficiaryName,
    String? beneficiaryLabel,
    String? beneficiaryAccountNumber,
    String? beneficiaryETransferAddress,
    String? securityQuestion,
    String? securityAnswer,
    String? paymentDescription,
    DateTime? completedAt,
    DateTime? sentAt,
    bool? isPPBitcoinOutUpdatable,
    PayinAmountChanged? payinAmountChanged,
    double? indexRateAmount,
    String? indexRateCurrency,
    DateTime? lightningVoucherExpiresAt,
    required bool isTestnet,
  }) = SellOrder;

  const factory Order.fiatPayment({
    required String orderId,
    required OrderType orderType,
    String? orderSubtype,
    required OrderMessage message,
    required int orderNumber,
    required double payinAmount,
    required String payinCurrency,
    required double payoutAmount,
    required String payoutCurrency,
    double? exchangeRateAmount,
    String? exchangeRateCurrency,
    required OrderPaymentMethod payinMethod,
    required OrderPaymentMethod payoutMethod,
    required OrderStatus orderStatus,
    required OrderPayinStatus payinStatus,
    required OrderPayoutStatus payoutStatus,
    required DateTime confirmationDeadline,
    required DateTime createdAt,
    DateTime? scheduledPayoutTime,
    String? beneficiaryName,
    String? beneficiaryLabel,
    String? beneficiaryAccountNumber,
    String? beneficiaryETransferAddress,
    String? securityQuestion,
    String? securityAnswer,
    String? paymentDescription,
    DateTime? completedAt,
    DateTime? sentAt,
    PayinAmountChanged? payinAmountChanged,
    double? indexRateAmount,
    String? indexRateCurrency,
    required bool isTestnet,
  }) = FiatPaymentOrder;

  const factory Order.funding({
    required String orderId,
    required OrderType orderType,
    String? orderSubtype,
    required OrderMessage message,
    required int orderNumber,
    required double payinAmount,
    required String payinCurrency,
    required double payoutAmount,
    required String payoutCurrency,
    required OrderPaymentMethod payinMethod,
    required OrderPaymentMethod payoutMethod,
    required OrderStatus orderStatus,
    required OrderPayinStatus payinStatus,
    required OrderPayoutStatus payoutStatus,
    required DateTime confirmationDeadline,
    required DateTime createdAt,
    DateTime? scheduledPayoutTime,
    String? beneficiaryName,
    String? beneficiaryLabel,
    String? beneficiaryAccountNumber,
    String? beneficiaryETransferAddress,
    String? securityQuestion,
    String? securityAnswer,
    String? paymentDescription,
    DateTime? completedAt,
    DateTime? sentAt,
    PayinAmountChanged? payinAmountChanged,
    required bool isTestnet,
  }) = FundingOrder;

  const factory Order.withdraw({
    required String orderId,
    required OrderType orderType,
    String? orderSubtype,
    required OrderMessage message,
    required int orderNumber,
    required double payinAmount,
    required String payinCurrency,
    required double payoutAmount,
    required String payoutCurrency,
    double? exchangeRateAmount,
    String? exchangeRateCurrency,
    required OrderPaymentMethod payinMethod,
    required OrderPaymentMethod payoutMethod,
    required OrderStatus orderStatus,
    required OrderPayinStatus payinStatus,
    required OrderPayoutStatus payoutStatus,
    required DateTime confirmationDeadline,
    required DateTime createdAt,
    DateTime? scheduledPayoutTime,
    String? beneficiaryName,
    String? beneficiaryLabel,
    String? beneficiaryAccountNumber,
    String? beneficiaryETransferAddress,
    String? securityQuestion,
    String? securityAnswer,
    String? paymentDescription,
    DateTime? completedAt,
    DateTime? sentAt,
    required bool isTestnet,
  }) = WithdrawOrder;

  const factory Order.reward({
    required String orderId,
    required OrderType orderType,
    String? orderSubtype,
    required OrderMessage message,
    required int orderNumber,
    required double payinAmount,
    required String payinCurrency,
    required double payoutAmount,
    required String payoutCurrency,
    double? exchangeRateAmount,
    String? exchangeRateCurrency,
    required OrderPaymentMethod payinMethod,
    required OrderPaymentMethod payoutMethod,
    required OrderStatus orderStatus,
    required OrderPayinStatus payinStatus,
    required OrderPayoutStatus payoutStatus,
    required DateTime confirmationDeadline,
    required DateTime createdAt,
    DateTime? scheduledPayoutTime,
    String? lightningInvoice,
    String? bitcoinAddress,
    String? bitcoinTransactionId,
    String? liquidAddress,
    String? liquidTransactionId,
    String? lightningAddress,
    String? lnUrl,
    String? beneficiaryName,
    String? beneficiaryLabel,
    String? beneficiaryAccountNumber,
    String? beneficiaryETransferAddress,
    String? securityQuestion,
    String? securityAnswer,
    String? paymentDescription,
    DateTime? completedAt,
    DateTime? sentAt,
    bool? isPPBitcoinOutUpdatable,
    PayinAmountChanged? payinAmountChanged,
    double? indexRateAmount,
    String? indexRateCurrency,
    DateTime? lightningVoucherExpiresAt,
    required bool isTestnet,
  }) = RewardOrder;

  const factory Order.refund({
    required String orderId,
    required OrderType orderType,
    String? orderSubtype,
    required OrderMessage message,
    required int orderNumber,
    required double payinAmount,
    required String payinCurrency,
    required double payoutAmount,
    required String payoutCurrency,
    double? exchangeRateAmount,
    String? exchangeRateCurrency,
    required OrderPaymentMethod payinMethod,
    required OrderPaymentMethod payoutMethod,
    required OrderStatus orderStatus,
    required OrderPayinStatus payinStatus,
    required OrderPayoutStatus payoutStatus,
    required DateTime confirmationDeadline,
    required DateTime createdAt,
    DateTime? scheduledPayoutTime,
    String? beneficiaryName,
    String? beneficiaryLabel,
    String? beneficiaryAccountNumber,
    String? beneficiaryETransferAddress,
    String? securityQuestion,
    String? securityAnswer,
    String? paymentDescription,
    DateTime? completedAt,
    DateTime? sentAt,
    required bool isTestnet,
  }) = RefundOrder;

  const factory Order.balanceAdjustment({
    required String orderId,
    required OrderType orderType,
    String? orderSubtype,
    required OrderMessage message,
    required int orderNumber,
    required double payinAmount,
    required String payinCurrency,
    required double payoutAmount,
    required String payoutCurrency,
    double? exchangeRateAmount,
    String? exchangeRateCurrency,
    required OrderPaymentMethod payinMethod,
    required OrderPaymentMethod payoutMethod,
    required OrderStatus orderStatus,
    required OrderPayinStatus payinStatus,
    required OrderPayoutStatus payoutStatus,
    required DateTime confirmationDeadline,
    required DateTime createdAt,
    DateTime? scheduledPayoutTime,
    String? lnUrl,
    String? beneficiaryName,
    String? beneficiaryLabel,
    String? beneficiaryAccountNumber,
    String? paymentDescription,
    DateTime? completedAt,
    DateTime? sentAt,
    required bool isTestnet,
  }) = BalanceAdjustmentOrder;

  bool get isPayinCompleted => payinStatus == OrderPayinStatus.completed;
  bool get isPayoutCompleted => payoutStatus == OrderPayoutStatus.completed;

  bool isCompleted() => orderStatus == OrderStatus.completed;
  bool isProcessing() => orderStatus == OrderStatus.inProgress;
  bool isCancelled() => orderStatus == OrderStatus.canceled;
  bool isExpired() => orderStatus == OrderStatus.expired;
  bool isPending() => orderStatus == OrderStatus.awaitingConfirmation;

  (num, String) amountAndCurrencyToDisplay() {
    if (orderType == OrderType.buy) {
      return (ConvertAmount.btcToSats(payoutAmount), 'sats');
    } else if (orderType == OrderType.sell) {
      return (ConvertAmount.btcToSats(payinAmount), 'sats');
    } else {
      return (payoutAmount, payoutCurrency);
    }
  }

  double absoluteUnbatchedBuyOnchainFees() {
    if (this is BuyOrder) {
      return (this as BuyOrder).unbatchedBuyOnchainFees != null
          ? (this as BuyOrder).unbatchedBuyOnchainFees! * 140.0
          : 0;
    }
    return 0;
  }

  String? get transactionId {
    switch (this) {
      case final BuyOrder buyOrder:
        return buyOrder.bitcoinTransactionId ?? buyOrder.liquidTransactionId;
      case final SellOrder sellOrder:
        return sellOrder.bitcoinTransactionId ?? sellOrder.liquidTransactionId;
      case _:
        return null;
    }
  }

  String? get toAddress {
    switch (this) {
      case final BuyOrder buyOrder:
        return buyOrder.bitcoinAddress ?? buyOrder.liquidAddress;
      case final SellOrder sellOrder:
        return sellOrder.bitcoinAddress ?? sellOrder.liquidAddress;
      case _:
        return null;
    }
  }

  bool get isLiquid {
    switch (this) {
      case final BuyOrder buyOrder:
        return buyOrder.liquidAddress != null;
      case final SellOrder sellOrder:
        return sellOrder.liquidAddress != null;
      case final FiatPaymentOrder fiatPaymentOrder:
        return fiatPaymentOrder.payinMethod == OrderPaymentMethod.liquid;
      case final RewardOrder rewardOrder:
        return rewardOrder.liquidAddress != null;
      default:
        return false;
    }
  }

  bool get isBitcoin {
    switch (this) {
      case final BuyOrder buyOrder:
        return buyOrder.bitcoinAddress != null;
      case final SellOrder sellOrder:
        return sellOrder.bitcoinAddress != null;
      case final FiatPaymentOrder fiatPaymentOrder:
        return fiatPaymentOrder.payinMethod == OrderPaymentMethod.bitcoin;
      case final RewardOrder rewardOrder:
        return rewardOrder.bitcoinAddress != null;
      default:
        return false;
    }
  }

  bool get isIncoming {
    switch (orderType) {
      case OrderType.buy:
      case OrderType.funding:
      case OrderType.balanceAdjustment:
      case OrderType.refund:
      case OrderType.reward:
        return true;
      case OrderType.sell:
      case OrderType.withdraw:
      case OrderType.fiatPayment:
        return false;
    }
  }
}
