import 'package:bb_mobile/core/exchange/domain/entity/announcement.dart';
import 'package:bb_mobile/core/exchange/domain/entity/default_wallet.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order_stats.dart';
import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message.dart';
import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message_attachment.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_api_failure.dart';
import 'package:bb_mobile/features/dca/public/dca_facade.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;

/// Maps `bbx_api` entities onto the exchange's own models and entities.
abstract final class BbxApiMapper {
  static ExchangeApiFailure apiFailure(bbx.ApiError error) =>
      switch (error.kind) {
        bbx.ApiErrorKind.network => const ExchangeApiNetworkFailure(),
        bbx.ApiErrorKind.timeout => const ExchangeApiTimeoutFailure(),
        bbx.ApiErrorKind.outcomeUnknown =>
          const ExchangeApiOutcomeUnknownFailure(),
        bbx.ApiErrorKind.unauthenticated =>
          const ExchangeApiUnauthenticatedFailure(),
        bbx.ApiErrorKind.validation => const ExchangeApiValidationFailure(),
        bbx.ApiErrorKind.maintenance => const ExchangeApiMaintenanceFailure(),
        bbx.ApiErrorKind.badCertificate ||
        bbx.ApiErrorKind.rateLimited ||
        bbx.ApiErrorKind.forbidden ||
        bbx.ApiErrorKind.notFound ||
        bbx.ApiErrorKind.server ||
        bbx.ApiErrorKind.parse ||
        bbx.ApiErrorKind.unknown => const ExchangeApiUnexpectedFailure(),
      };

  /// Whether [s] settled through [txId].
  ///
  /// A payjoin replaces the transaction the customer originally built, so the
  /// order's own payin/payout txid and the transaction that actually reached the
  /// chain can differ. Both are checked, otherwise a payjoin stops being linked
  /// back to its order.
  static bool orderMatchesTxId(bbx.OrderSummary s, String txId) =>
      s.bitcoinTransactionId == txId ||
      s.liquidTransactionId == txId ||
      s.payjoinDetails?.txid == txId;

  static Order orderFromSummary(bbx.OrderSummary s, {required bool isTestnet}) {
    final raw = s.raw;
    final orderId = s.orderId;
    final orderType = raw?.orderType ?? s.orderType.enumValue;
    final orderSubtype = s.orderSubtype;
    final orderNumber = s.orderNumber;
    final orderMsg = OrderMessage(
      code: s.message.code,
      message: s.message.message,
    );
    final exchangeRateAmount = s.exchangeRateAmount;
    final exchangeRateCurrency = s.exchangeRateCurrency;
    final indexRateAmount = s.indexRateAmount;
    final indexRateCurrency = s.indexRateCurrency;
    final payinAmount = s.payinAmount ?? 0;
    final payinCurrency = s.payinCurrency;
    final payoutAmount = s.payoutAmount ?? 0;
    final payoutCurrency = s.payoutCurrency;

    final orderTypeEnum =
        _fellBack(raw, (r) => r.orderType, bbx.OrderSummaryType.fromJson)
        ? OrderType.unknown
        : _orderType(s.orderType);
    final payinMethodEnum =
        _fellBack(
          raw,
          (r) => r.payinMethod,
          bbx.OrderSummaryPaymentMethod.fromJson,
        )
        ? OrderPaymentMethod.unknown
        : _paymentMethod(s.payinMethod);
    final payoutMethodEnum =
        _fellBack(
          raw,
          (r) => r.payoutMethod,
          bbx.OrderSummaryPaymentMethod.fromJson,
        )
        ? OrderPaymentMethod.unknown
        : _paymentMethod(s.payoutMethod);
    final orderStatusEnum =
        _fellBack(raw, (r) => r.orderStatus, bbx.OrderSummaryStatus.fromJson)
        ? OrderStatus.unknown
        : _orderStatus(s.orderStatus);
    final payinStatusEnum =
        _fellBack(
          raw,
          (r) => r.payinStatus,
          bbx.OrderSummaryPayinStatus.fromJson,
        )
        ? OrderPayinStatus.unknown
        : _payinStatus(s.payinStatus);
    final payoutStatusEnum =
        _fellBack(
          raw,
          (r) => r.payoutStatus,
          bbx.OrderSummaryPayoutStatus.fromJson,
        )
        ? OrderPayoutStatus.unknown
        : _payoutStatus(s.payoutStatus);

    // The package fills a missing deadline with the epoch.
    final confirmationDeadlineDt =
        s.confirmationDeadline.millisecondsSinceEpoch == 0
        ? null
        : s.confirmationDeadline;
    final createdAtDt = s.createdAt;
    final completedAtDt = s.completedAt;
    final sentAtDt = s.sentAt;
    final scheduledPayoutTimeDt = s.scheduledPayoutTime;
    final lightningVoucherExpiresAtDt = s.lightningVoucherExpiresAt;
    final changed = s.payinAmountChanged;
    final payinAmountChangedObj = changed == null
        ? null
        : PayinAmountChanged(
            requestedAmount: changed.requestedAmount,
            receivedAmount: changed.receivedAmount,
          );
    // txid is the only field mapped — see OrderPayjoinDetails for why. It stays
    // null until the exchange has actually seen the payjoin transaction.
    final payjoin = s.payjoinDetails;
    final payjoinDetailsObj = payjoin == null
        ? null
        : OrderPayjoinDetails(txid: payjoin.txid);
    final bitcoinTransactionId = s.bitcoinTransactionId;
    final lnUrl = s.lnUrl;
    final isPPBitcoinOutUpdatable = s.isPPBitcoinOutUpdatable;
    final lightningInvoice = s.lightningInvoice;
    final bitcoinAddress = s.bitcoinAddress;
    final liquidAddress = s.liquidAddress;
    final liquidTransactionId = s.liquidTransactionId;
    final lightningAddress = s.lightningAddress;
    final beneficiaryName = s.beneficiaryName;
    final beneficiaryLabel = s.beneficiaryLabel;
    final beneficiaryAccountNumber = s.beneficiaryAccountNumber;
    final beneficiaryETransferAddress = s.beneficiaryETransferAddress;
    final securityQuestion = s.securityQuestion;
    final securityAnswer = s.securityAnswer;
    final paymentDescription = s.paymentDescription;
    final unbatchedBuyOnchainFees = s.unbatchedBuyOnchainFees;
    final bip21URI = s.bip21URI;
    final referenceNumber = s.referenceNumber;
    final originName = s.originName;
    final originCedula = s.originCedula;

    switch (orderTypeEnum) {
      case OrderType.buy:
        return Order.buy(
          orderId: orderId,
          orderType: orderTypeEnum,
          orderSubtype: orderSubtype,
          message: orderMsg,
          orderNumber: orderNumber,
          payinAmount: payinAmount,
          payinCurrency: payinCurrency,
          payoutAmount: payoutAmount,
          payoutCurrency: payoutCurrency,
          exchangeRateAmount: exchangeRateAmount,
          exchangeRateCurrency: exchangeRateCurrency,
          payinMethod: payinMethodEnum,
          payoutMethod: payoutMethodEnum,
          orderStatus: orderStatusEnum,
          payinStatus: payinStatusEnum,
          payoutStatus: payoutStatusEnum,
          confirmationDeadline: confirmationDeadlineDt,
          createdAt: createdAtDt,
          scheduledPayoutTime: scheduledPayoutTimeDt,
          lightningInvoice: lightningInvoice,
          bitcoinAddress: bitcoinAddress,
          bitcoinTransactionId: bitcoinTransactionId,
          liquidAddress: liquidAddress,
          liquidTransactionId: liquidTransactionId,
          lightningAddress: lightningAddress,
          lnUrl: lnUrl,
          beneficiaryName: beneficiaryName,
          beneficiaryLabel: beneficiaryLabel,
          beneficiaryAccountNumber: beneficiaryAccountNumber,
          completedAt: completedAtDt,
          sentAt: sentAtDt,
          isPPBitcoinOutUpdatable: isPPBitcoinOutUpdatable,
          payinAmountChanged: payinAmountChangedObj,
          indexRateAmount: indexRateAmount,
          indexRateCurrency: indexRateCurrency,
          lightningVoucherExpiresAt: lightningVoucherExpiresAtDt,
          unbatchedBuyOnchainFees: unbatchedBuyOnchainFees,
          bip21URI: bip21URI,
          payjoinDetails: payjoinDetailsObj,
          isTestnet: isTestnet,
        );
      case OrderType.sell:
        return Order.sell(
          orderId: orderId,
          orderType: orderTypeEnum,
          orderSubtype: orderSubtype,
          message: orderMsg,
          orderNumber: orderNumber,
          payinAmount: payinAmount,
          payinCurrency: payinCurrency,
          payoutAmount: payoutAmount,
          payoutCurrency: payoutCurrency,
          exchangeRateAmount: exchangeRateAmount,
          exchangeRateCurrency: exchangeRateCurrency,
          payinMethod: payinMethodEnum,
          payoutMethod: payoutMethodEnum,
          orderStatus: orderStatusEnum,
          payinStatus: payinStatusEnum,
          payoutStatus: payoutStatusEnum,
          confirmationDeadline: confirmationDeadlineDt,
          createdAt: createdAtDt,
          scheduledPayoutTime: scheduledPayoutTimeDt,
          lightningInvoice: lightningInvoice,
          bitcoinAddress: bitcoinAddress,
          bitcoinTransactionId: bitcoinTransactionId,
          liquidAddress: liquidAddress,
          liquidTransactionId: liquidTransactionId,
          lightningAddress: lightningAddress,
          lnUrl: lnUrl,
          beneficiaryName: beneficiaryName,
          beneficiaryLabel: beneficiaryLabel,
          beneficiaryAccountNumber: beneficiaryAccountNumber,
          beneficiaryETransferAddress: beneficiaryETransferAddress,
          securityQuestion: securityQuestion,
          securityAnswer: securityAnswer,
          paymentDescription: paymentDescription,
          completedAt: completedAtDt,
          sentAt: sentAtDt,
          isPPBitcoinOutUpdatable: isPPBitcoinOutUpdatable,
          payinAmountChanged: payinAmountChangedObj,
          indexRateAmount: indexRateAmount,
          indexRateCurrency: indexRateCurrency,
          lightningVoucherExpiresAt: lightningVoucherExpiresAtDt,
          bip21URI: bip21URI,
          payjoinDetails: payjoinDetailsObj,
          isTestnet: isTestnet,
        );
      case OrderType.fiatPayment:
        return Order.fiatPayment(
          orderId: orderId,
          orderType: orderTypeEnum,
          orderSubtype: orderSubtype,
          message: orderMsg,
          orderNumber: orderNumber,
          payinAmount: payinAmount,
          payinCurrency: payinCurrency,
          payoutAmount: payoutAmount,
          payoutCurrency: payoutCurrency,
          exchangeRateAmount: exchangeRateAmount,
          exchangeRateCurrency: exchangeRateCurrency,
          payinMethod: payinMethodEnum,
          payoutMethod: payoutMethodEnum,
          orderStatus: orderStatusEnum,
          payinStatus: payinStatusEnum,
          payoutStatus: payoutStatusEnum,
          confirmationDeadline: confirmationDeadlineDt,
          createdAt: createdAtDt,
          scheduledPayoutTime: scheduledPayoutTimeDt,
          lightningInvoice: lightningInvoice,
          bitcoinAddress: bitcoinAddress,
          bitcoinTransactionId: bitcoinTransactionId,
          liquidAddress: liquidAddress,
          liquidTransactionId: liquidTransactionId,
          lightningAddress: lightningAddress,
          lnUrl: lnUrl,
          beneficiaryName: beneficiaryName,
          beneficiaryLabel: beneficiaryLabel,
          beneficiaryAccountNumber: beneficiaryAccountNumber,
          beneficiaryETransferAddress: beneficiaryETransferAddress,
          securityQuestion: securityQuestion,
          securityAnswer: securityAnswer,
          paymentDescription: paymentDescription,
          completedAt: completedAtDt,
          sentAt: sentAtDt,
          payinAmountChanged: payinAmountChangedObj,
          indexRateAmount: indexRateAmount,
          indexRateCurrency: indexRateCurrency,
          bip21URI: bip21URI,
          payjoinDetails: payjoinDetailsObj,
          isTestnet: isTestnet,
          referenceNumber: referenceNumber,
          originName: originName,
          originCedula: originCedula,
        );
      case OrderType.funding:
        return Order.funding(
          orderId: orderId,
          orderType: orderTypeEnum,
          orderSubtype: orderSubtype,
          message: orderMsg,
          orderNumber: orderNumber,
          payinAmount: payinAmount,
          payinCurrency: payinCurrency,
          payoutAmount: payoutAmount,
          payoutCurrency: payoutCurrency,
          payinMethod: payinMethodEnum,
          payoutMethod: payoutMethodEnum,
          orderStatus: orderStatusEnum,
          payinStatus: payinStatusEnum,
          payoutStatus: payoutStatusEnum,
          confirmationDeadline: confirmationDeadlineDt,
          createdAt: createdAtDt,
          scheduledPayoutTime: scheduledPayoutTimeDt,
          beneficiaryName: beneficiaryName,
          beneficiaryLabel: beneficiaryLabel,
          beneficiaryAccountNumber: beneficiaryAccountNumber,
          beneficiaryETransferAddress: beneficiaryETransferAddress,
          securityQuestion: securityQuestion,
          securityAnswer: securityAnswer,
          paymentDescription: paymentDescription,
          completedAt: completedAtDt,
          sentAt: sentAtDt,
          payinAmountChanged: payinAmountChangedObj,
          isTestnet: isTestnet,
        );
      case OrderType.withdraw:
        return Order.withdraw(
          orderId: orderId,
          orderType: orderTypeEnum,
          orderSubtype: orderSubtype,
          message: orderMsg,
          orderNumber: orderNumber,
          payinAmount: payinAmount,
          payinCurrency: payinCurrency,
          payoutAmount: payoutAmount,
          payoutCurrency: payoutCurrency,
          exchangeRateAmount: null,
          exchangeRateCurrency: null,
          payinMethod: payinMethodEnum,
          payoutMethod: payoutMethodEnum,
          orderStatus: orderStatusEnum,
          payinStatus: payinStatusEnum,
          payoutStatus: payoutStatusEnum,
          confirmationDeadline: confirmationDeadlineDt,
          createdAt: createdAtDt,
          scheduledPayoutTime: scheduledPayoutTimeDt,
          beneficiaryName: beneficiaryName,
          beneficiaryLabel: beneficiaryLabel,
          beneficiaryAccountNumber: beneficiaryAccountNumber,
          beneficiaryETransferAddress: beneficiaryETransferAddress,
          securityQuestion: securityQuestion,
          securityAnswer: securityAnswer,
          paymentDescription: paymentDescription,
          completedAt: completedAtDt,
          sentAt: sentAtDt,
          isTestnet: isTestnet,
        );
      case OrderType.reward:
        return Order.reward(
          orderId: orderId,
          orderType: orderTypeEnum,
          orderSubtype: orderSubtype,
          message: orderMsg,
          orderNumber: orderNumber,
          payinAmount: payinAmount,
          payinCurrency: payinCurrency,
          payoutAmount: payoutAmount,
          payoutCurrency: payoutCurrency,
          exchangeRateAmount: exchangeRateAmount,
          exchangeRateCurrency: exchangeRateCurrency,
          payinMethod: payinMethodEnum,
          payoutMethod: payoutMethodEnum,
          orderStatus: orderStatusEnum,
          payinStatus: payinStatusEnum,
          payoutStatus: payoutStatusEnum,
          confirmationDeadline: confirmationDeadlineDt,
          createdAt: createdAtDt,
          scheduledPayoutTime: scheduledPayoutTimeDt,
          lightningInvoice: lightningInvoice,
          bitcoinAddress: bitcoinAddress,
          bitcoinTransactionId: bitcoinTransactionId,
          liquidAddress: liquidAddress,
          liquidTransactionId: liquidTransactionId,
          lightningAddress: lightningAddress,
          lnUrl: lnUrl,
          beneficiaryName: beneficiaryName,
          beneficiaryLabel: beneficiaryLabel,
          beneficiaryAccountNumber: beneficiaryAccountNumber,
          beneficiaryETransferAddress: beneficiaryETransferAddress,
          securityQuestion: securityQuestion,
          securityAnswer: securityAnswer,
          paymentDescription: paymentDescription,
          completedAt: completedAtDt,
          sentAt: sentAtDt,
          isPPBitcoinOutUpdatable: isPPBitcoinOutUpdatable,
          payinAmountChanged: payinAmountChangedObj,
          indexRateAmount: indexRateAmount,
          indexRateCurrency: indexRateCurrency,
          lightningVoucherExpiresAt: lightningVoucherExpiresAtDt,
          isTestnet: isTestnet,
        );
      case OrderType.refund:
        return Order.refund(
          orderId: orderId,
          orderType: orderTypeEnum,
          orderSubtype: orderSubtype,
          message: orderMsg,
          orderNumber: orderNumber,
          payinAmount: payinAmount,
          payinCurrency: payinCurrency,
          payoutAmount: payoutAmount,
          payoutCurrency: payoutCurrency,
          exchangeRateAmount: exchangeRateAmount,
          exchangeRateCurrency: exchangeRateCurrency,
          payinMethod: payinMethodEnum,
          payoutMethod: payoutMethodEnum,
          orderStatus: orderStatusEnum,
          payinStatus: payinStatusEnum,
          payoutStatus: payoutStatusEnum,
          confirmationDeadline: confirmationDeadlineDt,
          createdAt: createdAtDt,
          scheduledPayoutTime: scheduledPayoutTimeDt,
          beneficiaryName: beneficiaryName,
          beneficiaryLabel: beneficiaryLabel,
          beneficiaryAccountNumber: beneficiaryAccountNumber,
          beneficiaryETransferAddress: beneficiaryETransferAddress,
          securityQuestion: securityQuestion,
          securityAnswer: securityAnswer,
          paymentDescription: paymentDescription,
          completedAt: completedAtDt,
          sentAt: sentAtDt,
          isTestnet: isTestnet,
        );
      case OrderType.balanceAdjustment:
        return Order.balanceAdjustment(
          orderId: orderId,
          orderType: orderTypeEnum,
          orderSubtype: orderSubtype,
          message: orderMsg,
          orderNumber: orderNumber,
          payinAmount: payinAmount,
          payinCurrency: payinCurrency,
          payoutAmount: payoutAmount,
          payoutCurrency: payoutCurrency,
          exchangeRateAmount: exchangeRateAmount,
          exchangeRateCurrency: exchangeRateCurrency,
          payinMethod: payinMethodEnum,
          payoutMethod: payoutMethodEnum,
          orderStatus: orderStatusEnum,
          payinStatus: payinStatusEnum,
          payoutStatus: payoutStatusEnum,
          confirmationDeadline: confirmationDeadlineDt,
          createdAt: createdAtDt,
          scheduledPayoutTime: scheduledPayoutTimeDt,
          lnUrl: lnUrl,
          beneficiaryName: beneficiaryName,
          beneficiaryLabel: beneficiaryLabel,
          beneficiaryAccountNumber: beneficiaryAccountNumber,
          paymentDescription: paymentDescription,
          completedAt: completedAtDt,
          sentAt: sentAtDt,
          isTestnet: isTestnet,
        );
      case OrderType.sellUsdt:
      case OrderType.unknown:
        return Order.generic(
          orderId: orderId,
          orderType: orderTypeEnum,
          orderTypeName: orderType,
          orderSubtype: orderSubtype,
          message: orderMsg,
          orderNumber: orderNumber,
          payinAmount: payinAmount,
          payinCurrency: payinCurrency,
          payoutAmount: payoutAmount,
          payoutCurrency: payoutCurrency,
          exchangeRateAmount: exchangeRateAmount,
          exchangeRateCurrency: exchangeRateCurrency,
          payinMethod: payinMethodEnum,
          payoutMethod: payoutMethodEnum,
          orderStatus: orderStatusEnum,
          payinStatus: payinStatusEnum,
          payoutStatus: payoutStatusEnum,
          confirmationDeadline: confirmationDeadlineDt,
          createdAt: createdAtDt,
          scheduledPayoutTime: scheduledPayoutTimeDt,
          paymentDescription: paymentDescription,
          completedAt: completedAtDt,
          sentAt: sentAtDt,
          isTestnet: isTestnet,
        );
    }
  }

  /// Whether the package replaced the value [field] reads from [raw] with a
  /// fallback: the server sent none, or one it does not know.
  static bool _fellBack(
    bbx.OrderSummaryRawValues? raw,
    String? Function(bbx.OrderSummaryRawValues raw) field,
    Object Function(String value) parse,
  ) {
    if (raw == null) return false;
    final value = field(raw);
    if (value == null) return true;
    try {
      parse(value);
      return false;
    } on Object {
      return true;
    }
  }

  static OrderType _orderType(bbx.OrderSummaryType type) => switch (type) {
    bbx.OrderSummaryType.buyBitcoin => OrderType.buy,
    bbx.OrderSummaryType.sellBitcoin => OrderType.sell,
    bbx.OrderSummaryType.sellUsdt => OrderType.sellUsdt,
    bbx.OrderSummaryType.fiatPayment => OrderType.fiatPayment,
    bbx.OrderSummaryType.funding => OrderType.funding,
    bbx.OrderSummaryType.withdraw => OrderType.withdraw,
    bbx.OrderSummaryType.reward => OrderType.reward,
    bbx.OrderSummaryType.refund => OrderType.refund,
    bbx.OrderSummaryType.balanceAdjustment => OrderType.balanceAdjustment,
    bbx.OrderSummaryType.swap ||
    bbx.OrderSummaryType.dca ||
    bbx.OrderSummaryType.limitOrder ||
    bbx.OrderSummaryType.autoBuy => OrderType.unknown,
  };

  static OrderStatus _orderStatus(bbx.OrderSummaryStatus status) =>
      switch (status) {
        bbx.OrderSummaryStatus.canceled => OrderStatus.canceled,
        bbx.OrderSummaryStatus.expired => OrderStatus.orderExpired,
        bbx.OrderSummaryStatus.paymentDeadlineExpired => OrderStatus.expired,
        bbx.OrderSummaryStatus.inProgress => OrderStatus.inProgress,
        bbx.OrderSummaryStatus.awaitingConfirmation =>
          OrderStatus.awaitingConfirmation,
        bbx.OrderSummaryStatus.completed => OrderStatus.completed,
        bbx.OrderSummaryStatus.rejected => OrderStatus.rejected,
      };

  static OrderPayinStatus _payinStatus(bbx.OrderSummaryPayinStatus status) =>
      switch (status) {
        bbx.OrderSummaryPayinStatus.notStarted => OrderPayinStatus.notStarted,
        bbx.OrderSummaryPayinStatus.awaitingPayment =>
          OrderPayinStatus.awaitingPayment,
        bbx.OrderSummaryPayinStatus.inProgress => OrderPayinStatus.inProgress,
        bbx.OrderSummaryPayinStatus.underReview => OrderPayinStatus.underReview,
        bbx.OrderSummaryPayinStatus.awaitingConfirmation =>
          OrderPayinStatus.awaitingConfirmation,
        bbx.OrderSummaryPayinStatus.completed => OrderPayinStatus.completed,
        bbx.OrderSummaryPayinStatus.rejected => OrderPayinStatus.rejected,
      };

  static OrderPayoutStatus _payoutStatus(bbx.OrderSummaryPayoutStatus status) =>
      switch (status) {
        bbx.OrderSummaryPayoutStatus.notStarted => OrderPayoutStatus.notStarted,
        bbx.OrderSummaryPayoutStatus.inProgress => OrderPayoutStatus.inProgress,
        bbx.OrderSummaryPayoutStatus.scheduled => OrderPayoutStatus.scheduled,
        bbx.OrderSummaryPayoutStatus.awaitingClaim =>
          OrderPayoutStatus.awaitingClaim,
        bbx.OrderSummaryPayoutStatus.completed => OrderPayoutStatus.completed,
        bbx.OrderSummaryPayoutStatus.failed => OrderPayoutStatus.failed,
        bbx.OrderSummaryPayoutStatus.canceled => OrderPayoutStatus.canceled,
      };

  static OrderPaymentMethod _paymentMethod(
    bbx.OrderSummaryPaymentMethod method,
  ) => switch (method) {
    bbx.OrderSummaryPaymentMethod.eTransfer => OrderPaymentMethod.eTransfer,
    bbx.OrderSummaryPaymentMethod.bankTransferArs =>
      OrderPaymentMethod.eTransferArs,
    bbx.OrderSummaryPaymentMethod.bankTransferCop =>
      OrderPaymentMethod.bankTransferCop,
    bbx.OrderSummaryPaymentMethod.billPayment => OrderPaymentMethod.billPayment,
    bbx.OrderSummaryPaymentMethod.bankTransfer =>
      OrderPaymentMethod.bankTransfer,
    bbx.OrderSummaryPaymentMethod.sepa => OrderPaymentMethod.sepa,
    bbx.OrderSummaryPaymentMethod.ibanCrc => OrderPaymentMethod.ibanCrc,
    bbx.OrderSummaryPaymentMethod.ibanUsd => OrderPaymentMethod.ibanUsd,
    bbx.OrderSummaryPaymentMethod.sinpe => OrderPaymentMethod.sinpe,
    bbx.OrderSummaryPaymentMethod.cadBalance => OrderPaymentMethod.cadBalance,
    bbx.OrderSummaryPaymentMethod.eurBalance => OrderPaymentMethod.eurBalance,
    bbx.OrderSummaryPaymentMethod.mxnBalance => OrderPaymentMethod.mxnBalance,
    bbx.OrderSummaryPaymentMethod.arsBalance => OrderPaymentMethod.arsBalance,
    bbx.OrderSummaryPaymentMethod.copBalance => OrderPaymentMethod.copBalance,
    bbx.OrderSummaryPaymentMethod.crcBalance => OrderPaymentMethod.crcBalance,
    bbx.OrderSummaryPaymentMethod.usdBalance => OrderPaymentMethod.usdBalance,
    bbx.OrderSummaryPaymentMethod.bitcoin => OrderPaymentMethod.bitcoin,
    bbx.OrderSummaryPaymentMethod.liquid => OrderPaymentMethod.liquid,
    bbx.OrderSummaryPaymentMethod.lnAddress => OrderPaymentMethod.lnAddress,
    bbx.OrderSummaryPaymentMethod.lnInvoice => OrderPaymentMethod.lnInvoice,
    bbx.OrderSummaryPaymentMethod.lnUrl => OrderPaymentMethod.lnUrl,
    bbx.OrderSummaryPaymentMethod.referralCad => OrderPaymentMethod.referralCad,
    bbx.OrderSummaryPaymentMethod.referralEur => OrderPaymentMethod.referralEur,
    bbx.OrderSummaryPaymentMethod.referralMxn => OrderPaymentMethod.referralMxn,
    bbx.OrderSummaryPaymentMethod.referralUsd => OrderPaymentMethod.referralUsd,
    bbx.OrderSummaryPaymentMethod.referralCrc => OrderPaymentMethod.referralCrc,
    bbx.OrderSummaryPaymentMethod.referralArs => OrderPaymentMethod.referralArs,
    bbx.OrderSummaryPaymentMethod.referralCop => OrderPaymentMethod.referralCop,
    bbx.OrderSummaryPaymentMethod.spei => OrderPaymentMethod.spei,
    bbx.OrderSummaryPaymentMethod.thinAir => OrderPaymentMethod.thinAir,
    bbx.OrderSummaryPaymentMethod.refundCrc => OrderPaymentMethod.refundCrc,
    bbx.OrderSummaryPaymentMethod.refundUsd => OrderPaymentMethod.refundUsd,
    bbx.OrderSummaryPaymentMethod.loadhub => OrderPaymentMethod.loadhub,
    bbx.OrderSummaryPaymentMethod.refundEur ||
    bbx.OrderSummaryPaymentMethod.usdBvcu ||
    bbx.OrderSummaryPaymentMethod.usdUsBalance ||
    bbx.OrderSummaryPaymentMethod.usdBankTransfer => OrderPaymentMethod.unknown,
  };

  static Dca dcaFromRecurringBuy(bbx.RecurringBuyOrderSummary s) => Dca(
    amount: double.parse(s.amount),
    currency: FiatCurrency.fromCode(s.currencyCode),
    frequency:
        _dcaFrequency(s.recurringFrequency) ??
        (throw FormatException('Unknown frequency: ${s.recurringFrequency}')),
    network:
        _dcaNetwork(s.recipientType) ??
        (throw FormatException('Unknown network: ${s.recipientType}')),
    address: s.address,
    nextPurchaseDate: s.nextRunAt,
  );

  static DcaBuyFrequency? _dcaFrequency(bbx.DCARecurringFrequencyType? f) =>
      switch (f) {
        bbx.DCARecurringFrequencyType.hourly => DcaBuyFrequency.hourly,
        bbx.DCARecurringFrequencyType.daily => DcaBuyFrequency.daily,
        bbx.DCARecurringFrequencyType.weekly => DcaBuyFrequency.weekly,
        bbx.DCARecurringFrequencyType.monthly => DcaBuyFrequency.monthly,
        bbx.DCARecurringFrequencyType.none || null => null,
      };

  static DcaNetwork? _dcaNetwork(bbx.RecipientType? type) => switch (type) {
    bbx.RecipientType.outBitcoinAddress => DcaNetwork.bitcoin,
    bbx.RecipientType.outLightningAddress => DcaNetwork.lightning,
    bbx.RecipientType.outLiquidAddress => DcaNetwork.liquid,
    _ => null,
  };

  static UserSummary userSummary(bbx.UserSummary s) {
    final dca = s.dca;
    final docs = s.kycDocumentStatus;
    return UserSummary(
      userNumber: s.userNumber,
      userId: s.userId,
      groups: s.groups,
      profile: UserProfile(
        firstName: s.profile.firstName,
        lastName: s.profile.lastName,
      ),
      email: s.email,
      balances: [
        for (final b in s.balances)
          UserBalance(amount: b.amount, currencyCode: b.currencyCode),
      ],
      language: s.language,
      currency: s.currency,
      dca: UserDca(
        isActive: dca.isActive,
        frequency: _dcaFrequency(dca.frequency),
        amount: dca.amount,
        currency: switch (dca.currencyCode) {
          final code? => FiatCurrency.tryFromCode(code),
          null => null,
        },
        network: _dcaNetwork(dca.recipientType),
        address: dca.address,
      ),
      autoBuy: UserAutoBuy(
        isActive: s.autoBuy.isActive,
        addresses: UserAutoBuyAddresses(
          bitcoin: s.autoBuy.addresses.bitcoin,
          lightning: s.autoBuy.addresses.lightning,
          liquid: s.autoBuy.addresses.liquid,
        ),
      ),
      emailNotificationsEnabled: s.emailNotificationsEnabled,
      payjoinReceiveEnabled: s.payjoinReceiveEnabled,
      kycDocumentStatus: UserKycDocumentStatus(
        secureFileUpload: _kycStatus(docs.secureFileUpload),
        documents: UserKycDocuments(
          id: _kycStatus(docs.documents.id),
          proofOfResidence: _kycStatus(docs.documents.proofOfResidence),
          selfie: _kycStatus(docs.documents.selfie),
        ),
      ),
    );
  }

  static KycDocumentStatus _kycStatus(
    bbx.UserSumKycDocumentStatus status,
  ) => switch (status) {
    bbx.UserSumKycDocumentStatus.accepted => KycDocumentStatus.accepted,
    bbx.UserSumKycDocumentStatus.underReview => KycDocumentStatus.underReview,
    bbx.UserSumKycDocumentStatus.rejected => KycDocumentStatus.rejected,
    bbx.UserSumKycDocumentStatus.notUploaded => KycDocumentStatus.notUploaded,
  };

  static Announcement announcement(bbx.Announcement a) => Announcement(
    title: a.title,
    description: a.description,
    updatedAt: a.updatedAt,
  );

  static SupportChatMessage supportChatMessage(bbx.BBMessage m) =>
      SupportChatMessage(
        messageId: m.messageId,
        text: m.text,
        fromUserId: m.fromUserId,
        toGroupCode: m.toGroupCode,
        createdAt: m.createdAt,
        updatedAt: m.updatedAt,
        isAdmin: m.isAdmin,
        attachments: m.attachments
            ?.map(
              (a) => supportChatAttachment(a, fallbackMessageId: m.messageId),
            )
            .where((a) => a.attachmentId != null || a.fileName != null)
            .toList(),
      );

  static SupportChatMessageAttachment supportChatAttachment(
    bbx.BBMessageAttachment a, {
    String? fallbackMessageId,
  }) => SupportChatMessageAttachment(
    attachmentId: a.attachmentId,
    fileName: a.fileName,
    fileType: a.fileType,
    fileSize: a.fileSize,
    fileData: a.fileData,
    messageId: a.messageId ?? fallbackMessageId,
    createdAt: a.createdAt,
  );

  static bbx.BBMessageAttachment outgoingAttachment(
    SupportChatMessageAttachment a,
  ) => bbx.BBMessageAttachment(
    fileName: a.fileName,
    fileType: a.fileType,
    fileSize: a.fileSize,
    fileData: a.fileData,
  );

  static OrderStatsResponse orderStats(bbx.OrderStatsResponse r) {
    List<AmountByCurrencyCode> amounts(List<bbx.AmountByCurrencyCode> list) => [
      for (final a in list)
        AmountByCurrencyCode(currency: a.currency, value: a.value),
    ];
    final s = r.orderStats;
    return OrderStatsResponse(
      orderStats: OrderStats(
        bitcoinBuyVolume: amounts(s.bitcoinBuyVolume),
        bitcoinBuyTradeCount: amounts(s.bitcoinBuyTradeCount),
        averageBitcoinBuyPrice: amounts(s.averageBitcoinBuyPrice),
        bitcoinSellVolume: amounts(s.bitcoinSellVolume),
        bitcoinSellTradeCount: amounts(s.bitcoinSellTradeCount),
        averageBitcoinSellPrice: amounts(s.averageBitcoinSellPrice),
        totalBitcoinTradingVolume: amounts(s.totalBitcoinTradingVolume),
        buySellRatio: s.buySellRatio,
      ),
      billerStats: BillerStats(
        currency: r.billerStats.currency,
        stats: [
          for (final b in r.billerStats.stats)
            BillerStat(
              billerName: b.billerName,
              billerCode: b.billerCode,
              totalAmount: b.totalAmount,
              tradeCount: b.tradeCount,
            ),
        ],
      ),
      asOf: r.asOf,
    );
  }

  static DefaultWallet defaultWallet(bbx.Recipient r) => DefaultWallet(
    recipientId: r.recipientId,
    walletType: switch (r.recipientType) {
      bbx.RecipientType.outLightningAddress => WalletAddressType.lightning,
      bbx.RecipientType.outLiquidAddress => WalletAddressType.liquid,
      _ => WalletAddressType.bitcoin,
    },
    address:
        r.address ??
        r.bitcoinAddress ??
        r.lightningAddress ??
        r.liquidAddress ??
        '',
    isDefault: r.isDefault ?? false,
  );

  static bbx.RecipientType recipientType(WalletAddressType type) =>
      switch (type) {
        WalletAddressType.bitcoin => bbx.RecipientType.outBitcoinAddress,
        WalletAddressType.lightning => bbx.RecipientType.outLightningAddress,
        WalletAddressType.liquid => bbx.RecipientType.outLiquidAddress,
      };
}
