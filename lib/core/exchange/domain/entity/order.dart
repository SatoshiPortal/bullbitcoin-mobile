import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'order.freezed.dart';

enum FiatCurrency {
  usd('USD', decimals: 2, symbol: '\$'),
  cad('CAD', decimals: 2, symbol: '\$'),
  crc('CRC', decimals: 2, symbol: '₡'),
  eur('EUR', decimals: 2, symbol: '€'),
  mxn('MXN', decimals: 2, symbol: '\$'),
  ars('ARS', decimals: 2, symbol: '\$'),
  cop('COP', decimals: 0, symbol: '\$');

  const FiatCurrency(this.code, {required this.decimals, required this.symbol});
  final String code;
  final int decimals;
  final String symbol;

  static FiatCurrency fromCode(String code) {
    final currency = tryFromCode(code);
    if (currency == null) throw Exception('Unknown FiatCurrency: $code');
    return currency;
  }

  // Nullable counterpart of [fromCode], for parsing server payloads where a
  // currency this build doesn't support must not fail the whole response.
  // There is deliberately no `unknown` member: [FiatCurrency.values] populates
  // the user-facing currency pickers.
  static FiatCurrency? tryFromCode(String code) {
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
      case 'ARS':
        return FiatCurrency.ars;
      case 'COP':
        return FiatCurrency.cop;
      default:
        return null;
    }
  }
}

enum OrderType {
  buy('Buy Bitcoin'),
  sell('Sell Bitcoin'),
  sellUsdt('Sell USDT'),
  fiatPayment('Fiat Payment'),
  funding('Funding'),
  withdraw('Withdraw'),
  reward('Reward'),
  refund('Refund'),
  balanceAdjustment('Balance Adjustment'),
  // Order types added server-side after this build shipped. The raw string is
  // carried on [GenericOrder.orderTypeName] instead of here, since an enum
  // member can't be parameterized — same trade-off as [OrderPaymentMethod].
  unknown('Unknown');

  final String value;
  const OrderType(this.value);

  static OrderType fromValue(String value) {
    return OrderType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => OrderType.unknown,
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
  // The server sends both of these as distinct statuses: `expired` is the
  // pay-in deadline lapsing, `orderExpired` the order itself expiring.
  expired('Payment deadline expired'),
  orderExpired('Expired'),
  inProgress('In progress'),
  awaitingConfirmation('Awaiting confirmation'),
  completed('Completed'),
  rejected('Rejected'),
  failed('Failed'),
  unknown('Unknown');

  final String value;
  const OrderStatus(this.value);

  static OrderStatus fromValue(String value) {
    return OrderStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => OrderStatus.unknown,
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
  rejected('Rejected'),
  unknown('Unknown');

  final String value;
  const OrderPayinStatus(this.value);

  static OrderPayinStatus fromValue(String value) {
    return OrderPayinStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => OrderPayinStatus.unknown,
    );
  }
}

enum OrderPayoutStatus {
  notStarted('Not started'),
  inProgress('In progress'),
  scheduled('Scheduled'),
  awaitingClaim('Awaiting claim'),
  completed('Completed'),
  canceled('Canceled'),
  failed('Failed'),
  unknown('Unknown');

  final String value;
  const OrderPayoutStatus(this.value);

  static OrderPayoutStatus fromValue(String value) {
    return OrderPayoutStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => OrderPayoutStatus.unknown,
    );
  }
}

// enum WithdrawalPaymentProcessor {
//   // CANADA
//   interacEmailCad(code: 'INTERAC_EMAIL_CAD', currencyCode: 'CAD'),
//   billPaymentCad(code: 'BILL_PAYMENT_CAD', currencyCode: 'CAD'),
//   bankTransferCad(code: 'BANK_TRANSFER_CAD', currencyCode: 'CAD'),

//   // EUROPE
//   sepaEur(code: 'SEPA_EUR', currencyCode: 'EUR'),

//   // MEXICO
//   speiClabeMxn(code: 'SPEI_CLABE_MXN', currencyCode: 'MXN'),
//   speiSmsMxn(code: 'SPEI_SMS_MXN', currencyCode: 'MXN'),
//   speiCardMxn(code: 'SPEI_CARD_MXN', currencyCode: 'MXN'),

//   // COSTA RICA
//   sinpeIbanUsd(code: 'SINPE_IBAN_USD', currencyCode: 'USD'),
//   sinpeIbanCrc(code: 'SINPE_IBAN_CRC', currencyCode: 'CRC'),
//   sinpeMovilCrc(code: 'SINPE_MOVIL_CRC', currencyCode: 'CRC');

//   final String code;
//   final String currencyCode;
//   const WithdrawalPaymentProcessor({
//     required this.code,
//     required this.currencyCode,
//   });

//   static WithdrawalPaymentProcessor fromCode(String code) {
//     return WithdrawalPaymentProcessor.values.firstWhere(
//       (e) => e.code == code,
//       orElse:
//           () => throw Exception('Unknown WithdrawalPaymentProcessor: $code'),
//     );
//   }
// }

enum OrderPaymentMethod {
  eTransfer('Interac e-Transfer (CAD)'),
  eTransferArs('Bank Transfer CBU (ARS)'),
  bankTransferCop('PSE Colombia (COP)'),
  billPayment('Bill Payment (CAD)'),
  bankTransfer('Bank Transfer EFT (CAD)'),
  sepa('SEPA Transfer (EUR)'),
  ibanCrc('SINPE IBAN (CRC)'),
  ibanUsd('SINPE IBAN (USD)'),
  sinpe('SINPE Móvil (CRC)'),
  cadBalance('CAD Balance'),
  eurBalance('EUR Balance'),
  mxnBalance('MXN Balance'),
  arsBalance('ARS Balance'),
  copBalance('COP Balance'),
  crcBalance('CRC Balance'),
  usdBalance('USD Balance'),
  bitcoin('Bitcoin On-Chain'),
  liquid('Liquid Network'),
  lnAddress('Lightning Address (LNURL-PAY)'),
  lnInvoice('Lightning Invoice (BOLT11)'),
  lnUrl('LNURL-Withdraw'),
  referralCad('Referral Payout CAD'),
  referralEur('Referral Payout EUR'),
  referralMxn('Referral Payout MXN'),
  referralUsd('Referral Payout USD'),
  referralCrc('Referral Payout CRC'),
  referralArs('Referral Payout ARS'),
  referralCop('Referral Payout COP'),
  spei('SPEI transfer (MXN)'),
  thinAir('Thin Air'),
  refundCrc('Refund to CRC Balance'),
  refundUsd('Refund to USD Balance'),
  loadhub('Canada Post In-Person Deposit (CAD)'),
  unknown(
    'Unknown', // If we want this value to be parameterizable with the value of the unknown payment method, we shouldn't use an enum but classes with factory constructor
  );

  final String value;
  const OrderPaymentMethod(this.value);

  /// The payin/payout methods that debit or credit one of the user's in-app
  /// fiat balances instead of an external account. Refund-to-balance methods
  /// are deliberately excluded: they are not selectable as a payout.
  static const balanceMethods = <OrderPaymentMethod>{
    cadBalance,
    eurBalance,
    mxnBalance,
    arsBalance,
    copBalance,
    crcBalance,
    usdBalance,
  };

  bool get isBalance => balanceMethods.contains(this);

  static OrderPaymentMethod fromValue(String value) {
    return OrderPaymentMethod.values.firstWhere(
      (e) => e.value == value,
      orElse: () => OrderPaymentMethod.unknown,
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
    DateTime? confirmationDeadline,
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
    DateTime? confirmationDeadline,
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
    DateTime? confirmationDeadline,
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
    PayinAmountChanged? payinAmountChanged,
    double? indexRateAmount,
    String? indexRateCurrency,
    required bool isTestnet,
    String? referenceNumber,
    String? originName,
    String? originCedula,
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
    DateTime? confirmationDeadline,
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
    DateTime? confirmationDeadline,
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
    DateTime? confirmationDeadline,
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
    DateTime? confirmationDeadline,
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
    DateTime? confirmationDeadline,
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

  /// Order types that have no dedicated flow in the app: ones we know of but
  /// don't handle specially ('Sell USDT'), and ones added server-side after this
  /// build shipped ([OrderType.unknown]). They still render in the transaction
  /// list — with [orderTypeName], the amount and the status — instead of being
  /// dropped, which is what an unparseable order used to cost us.
  const factory Order.generic({
    required String orderId,
    required OrderType orderType,
    required String orderTypeName,
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
    DateTime? confirmationDeadline,
    required DateTime createdAt,
    DateTime? scheduledPayoutTime,
    String? paymentDescription,
    DateTime? completedAt,
    DateTime? sentAt,
    required bool isTestnet,
  }) = GenericOrder;

  bool get isPayinCompleted => payinStatus == OrderPayinStatus.completed;
  bool get isPayoutCompleted => payoutStatus == OrderPayoutStatus.completed;

  /// Whether the payout credits one of the user's in-app fiat balances rather
  /// than an external recipient.
  bool get isBalancePayout => payoutMethod.isBalance;

  bool isCompleted() => orderStatus == OrderStatus.completed;
  bool isProcessing() => orderStatus == OrderStatus.inProgress;
  bool isCancelled() => orderStatus == OrderStatus.canceled;
  bool isExpired() =>
      orderStatus == OrderStatus.expired ||
      orderStatus == OrderStatus.orderExpired;
  bool isPending() => orderStatus == OrderStatus.awaitingConfirmation;

  /// Label for the order type. A [GenericOrder] reports the server-sent string,
  /// so a type this build doesn't know still reads correctly in the UI.
  String get orderTypeLabel => switch (this) {
    final GenericOrder order => order.orderTypeName,
    _ => orderType.value,
  };

  /// Whether [amountAndCurrencyToDisplay] returns a fiat amount rather than sats.
  bool get displaysFiatAmount => amountAndCurrencyToDisplay().$2 != 'sats';

  (num, String) amountAndCurrencyToDisplay() {
    if (orderType == OrderType.buy) {
      return (ConvertAmount.btcToSats(payoutAmount), 'sats');
    }
    if (orderType == OrderType.sell) {
      return (ConvertAmount.btcToSats(payinAmount), 'sats');
    }

    final (amount, currency) = switch (orderType) {
      // Rewards are admin-initiated: there is no real pay-in, so the credit is
      // only on the payout side.
      OrderType.reward => (payoutAmount, payoutCurrency),
      OrderType.refund => (payoutAmount, payoutCurrency),
      _ => (payoutAmount, payoutCurrency),
    };
    if (currency == 'BTC' || currency == 'LBTC') {
      return (ConvertAmount.btcToSats(amount), 'sats');
    }
    return (amount, currency);
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
      case final FiatPaymentOrder fiatPaymentOrder:
        return fiatPaymentOrder.bitcoinTransactionId ??
            fiatPaymentOrder.liquidTransactionId;
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
      case final FiatPaymentOrder fiatPaymentOrder:
        return fiatPaymentOrder.bitcoinAddress ??
            fiatPaymentOrder.liquidAddress;
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
      // Direction isn't known for these, so they stay out of the Receive filter.
      case OrderType.sellUsdt:
      case OrderType.unknown:
        return false;
    }
  }
}

extension FiatPaymentOrderDisplayX on FiatPaymentOrder {
  /// The fiat amount the recipient gets, e.g. "125.00 CAD". The currency code
  /// is used as returned by the server, without going through
  /// [FiatCurrency.fromCode], which throws on codes the app doesn't know yet.
  String get payoutAmountToDisplay =>
      '${payoutAmount.toStringAsFixed(2)} $payoutCurrency';

  /// The recipient as shown to the user. The server populates
  /// [beneficiaryName] for most payout processors, but not all (SINPE can
  /// legitimately have no owner name), so fall back to the label the user gave
  /// the recipient and then to whichever identifier the payout method carries.
  /// Null when the order carries nothing identifying at all.
  String? get recipientToDisplay {
    for (final candidate in [
      beneficiaryName,
      beneficiaryLabel,
      beneficiaryAccountNumber,
      beneficiaryETransferAddress,
      lightningAddress,
    ]) {
      if (candidate != null && candidate.isNotEmpty) return candidate;
    }
    return null;
  }
}
