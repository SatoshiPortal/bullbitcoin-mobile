import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;

/// Whether [s] settled through [txId].
///
/// A payjoin replaces the transaction the customer originally built, so the
/// order's own payin/payout txid and the transaction that actually reached the
/// chain can differ. Both are checked, otherwise a payjoin stops being linked
/// back to its order.
bool orderSummaryMatchesTxId(bbx.OrderSummary s, String txId) =>
    s.bitcoinTransactionId == txId ||
    s.liquidTransactionId == txId ||
    s.payjoinDetails?.txid == txId;

/// Maps a `bbx_api` order to the app entity, with the defaults the exchange
/// order parser has always applied: missing amounts are 0, missing strings
/// are empty and unparseable optional dates are null.
///
/// Throws a [FormatException] when `createdAt` is not a date.
Order orderFromBbxApi(bbx.OrderSummary s, {required bool isTestnet}) {
  final orderMsg = OrderMessage(
    code: s.message?.code ?? '',
    message: s.message?.message ?? '',
  );
  final payinAmount = s.payinAmount ?? 0;
  final payinCurrency = s.payinCurrency ?? '';
  final payoutAmount = s.payoutAmount ?? 0;
  final payoutCurrency = s.payoutCurrency ?? '';

  final orderTypeEnum = OrderType.fromValue(s.orderType);
  final payinMethodEnum = OrderPaymentMethod.fromValue(s.payinMethod ?? '');
  final payoutMethodEnum = OrderPaymentMethod.fromValue(s.payoutMethod ?? '');
  final orderStatusEnum = OrderStatus.fromValue(s.orderStatus ?? '');
  final payinStatusEnum = OrderPayinStatus.fromValue(s.payinStatus ?? '');
  final payoutStatusEnum = OrderPayoutStatus.fromValue(s.payoutStatus ?? '');
  final confirmationDeadlineDt = _tryParse(s.confirmationDeadline);
  final createdAtDt = DateTime.parse(s.createdAt);
  final completedAtDt = _tryParse(s.completedAt);
  final sentAtDt = _tryParse(s.sentAt);
  final scheduledPayoutTimeDt = _tryParse(s.scheduledPayoutTime);
  final lightningVoucherExpiresAtDt = _tryParse(s.lightningVoucherExpiresAt);
  final payinAmountChangedObj = switch (s.payinAmountChanged) {
    final changed? => PayinAmountChanged(
      requestedAmount: changed.requestedAmount ?? 0,
      receivedAmount: changed.receivedAmount ?? 0,
    ),
    null => null,
  };
  // txid is the only field mapped: see OrderPayjoinDetails.
  final payjoinDetailsObj = switch (s.payjoinDetails) {
    final details? => OrderPayjoinDetails(txid: details.txid),
    null => null,
  };

  switch (orderTypeEnum) {
    case OrderType.buy:
      return Order.buy(
        orderId: s.orderId,
        orderType: orderTypeEnum,
        orderSubtype: s.orderSubtype,
        message: orderMsg,
        orderNumber: s.orderNumber,
        payinAmount: payinAmount,
        payinCurrency: payinCurrency,
        payoutAmount: payoutAmount,
        payoutCurrency: payoutCurrency,
        exchangeRateAmount: s.exchangeRateAmount,
        exchangeRateCurrency: s.exchangeRateCurrency,
        payinMethod: payinMethodEnum,
        payoutMethod: payoutMethodEnum,
        orderStatus: orderStatusEnum,
        payinStatus: payinStatusEnum,
        payoutStatus: payoutStatusEnum,
        confirmationDeadline: confirmationDeadlineDt,
        createdAt: createdAtDt,
        scheduledPayoutTime: scheduledPayoutTimeDt,
        lightningInvoice: s.lightningInvoice,
        bitcoinAddress: s.bitcoinAddress,
        bitcoinTransactionId: s.bitcoinTransactionId,
        liquidAddress: s.liquidAddress,
        liquidTransactionId: s.liquidTransactionId,
        lightningAddress: s.lightningAddress,
        lnUrl: s.lnUrl,
        beneficiaryName: s.beneficiaryName,
        beneficiaryLabel: s.beneficiaryLabel,
        beneficiaryAccountNumber: s.beneficiaryAccountNumber,
        completedAt: completedAtDt,
        sentAt: sentAtDt,
        isPPBitcoinOutUpdatable: s.isPPBitcoinOutUpdatable,
        payinAmountChanged: payinAmountChangedObj,
        indexRateAmount: s.indexRateAmount,
        indexRateCurrency: s.indexRateCurrency,
        lightningVoucherExpiresAt: lightningVoucherExpiresAtDt,
        unbatchedBuyOnchainFees: s.unbatchedBuyOnchainFees,
        bip21URI: s.bip21URI,
        payjoinDetails: payjoinDetailsObj,
        isTestnet: isTestnet,
      );
    case OrderType.sell:
      return Order.sell(
        orderId: s.orderId,
        orderType: orderTypeEnum,
        orderSubtype: s.orderSubtype,
        message: orderMsg,
        orderNumber: s.orderNumber,
        payinAmount: payinAmount,
        payinCurrency: payinCurrency,
        payoutAmount: payoutAmount,
        payoutCurrency: payoutCurrency,
        exchangeRateAmount: s.exchangeRateAmount,
        exchangeRateCurrency: s.exchangeRateCurrency,
        payinMethod: payinMethodEnum,
        payoutMethod: payoutMethodEnum,
        orderStatus: orderStatusEnum,
        payinStatus: payinStatusEnum,
        payoutStatus: payoutStatusEnum,
        confirmationDeadline: confirmationDeadlineDt,
        createdAt: createdAtDt,
        scheduledPayoutTime: scheduledPayoutTimeDt,
        lightningInvoice: s.lightningInvoice,
        bitcoinAddress: s.bitcoinAddress,
        bitcoinTransactionId: s.bitcoinTransactionId,
        liquidAddress: s.liquidAddress,
        liquidTransactionId: s.liquidTransactionId,
        lightningAddress: s.lightningAddress,
        lnUrl: s.lnUrl,
        beneficiaryName: s.beneficiaryName,
        beneficiaryLabel: s.beneficiaryLabel,
        beneficiaryAccountNumber: s.beneficiaryAccountNumber,
        beneficiaryETransferAddress: s.beneficiaryETransferAddress,
        securityQuestion: s.securityQuestion,
        securityAnswer: s.securityAnswer,
        paymentDescription: s.paymentDescription,
        completedAt: completedAtDt,
        sentAt: sentAtDt,
        isPPBitcoinOutUpdatable: s.isPPBitcoinOutUpdatable,
        payinAmountChanged: payinAmountChangedObj,
        indexRateAmount: s.indexRateAmount,
        indexRateCurrency: s.indexRateCurrency,
        lightningVoucherExpiresAt: lightningVoucherExpiresAtDt,
        bip21URI: s.bip21URI,
        payjoinDetails: payjoinDetailsObj,
        isTestnet: isTestnet,
      );
    case OrderType.fiatPayment:
      return Order.fiatPayment(
        orderId: s.orderId,
        orderType: orderTypeEnum,
        orderSubtype: s.orderSubtype,
        message: orderMsg,
        orderNumber: s.orderNumber,
        payinAmount: payinAmount,
        payinCurrency: payinCurrency,
        payoutAmount: payoutAmount,
        payoutCurrency: payoutCurrency,
        exchangeRateAmount: s.exchangeRateAmount,
        exchangeRateCurrency: s.exchangeRateCurrency,
        payinMethod: payinMethodEnum,
        payoutMethod: payoutMethodEnum,
        orderStatus: orderStatusEnum,
        payinStatus: payinStatusEnum,
        payoutStatus: payoutStatusEnum,
        confirmationDeadline: confirmationDeadlineDt,
        createdAt: createdAtDt,
        scheduledPayoutTime: scheduledPayoutTimeDt,
        lightningInvoice: s.lightningInvoice,
        bitcoinAddress: s.bitcoinAddress,
        bitcoinTransactionId: s.bitcoinTransactionId,
        liquidAddress: s.liquidAddress,
        liquidTransactionId: s.liquidTransactionId,
        lightningAddress: s.lightningAddress,
        lnUrl: s.lnUrl,
        beneficiaryName: s.beneficiaryName,
        beneficiaryLabel: s.beneficiaryLabel,
        beneficiaryAccountNumber: s.beneficiaryAccountNumber,
        beneficiaryETransferAddress: s.beneficiaryETransferAddress,
        securityQuestion: s.securityQuestion,
        securityAnswer: s.securityAnswer,
        paymentDescription: s.paymentDescription,
        completedAt: completedAtDt,
        sentAt: sentAtDt,
        payinAmountChanged: payinAmountChangedObj,
        indexRateAmount: s.indexRateAmount,
        indexRateCurrency: s.indexRateCurrency,
        bip21URI: s.bip21URI,
        payjoinDetails: payjoinDetailsObj,
        isTestnet: isTestnet,
        referenceNumber: s.referenceNumber,
        originName: s.originName,
        originCedula: s.originCedula,
      );
    case OrderType.funding:
      return Order.funding(
        orderId: s.orderId,
        orderType: orderTypeEnum,
        orderSubtype: s.orderSubtype,
        message: orderMsg,
        orderNumber: s.orderNumber,
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
        beneficiaryName: s.beneficiaryName,
        beneficiaryLabel: s.beneficiaryLabel,
        beneficiaryAccountNumber: s.beneficiaryAccountNumber,
        beneficiaryETransferAddress: s.beneficiaryETransferAddress,
        securityQuestion: s.securityQuestion,
        securityAnswer: s.securityAnswer,
        paymentDescription: s.paymentDescription,
        completedAt: completedAtDt,
        sentAt: sentAtDt,
        payinAmountChanged: payinAmountChangedObj,
        isTestnet: isTestnet,
      );
    case OrderType.withdraw:
      return Order.withdraw(
        orderId: s.orderId,
        orderType: orderTypeEnum,
        orderSubtype: s.orderSubtype,
        message: orderMsg,
        orderNumber: s.orderNumber,
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
        beneficiaryName: s.beneficiaryName,
        beneficiaryLabel: s.beneficiaryLabel,
        beneficiaryAccountNumber: s.beneficiaryAccountNumber,
        beneficiaryETransferAddress: s.beneficiaryETransferAddress,
        securityQuestion: s.securityQuestion,
        securityAnswer: s.securityAnswer,
        paymentDescription: s.paymentDescription,
        completedAt: completedAtDt,
        sentAt: sentAtDt,
        isTestnet: isTestnet,
      );
    case OrderType.reward:
      return Order.reward(
        orderId: s.orderId,
        orderType: orderTypeEnum,
        orderSubtype: s.orderSubtype,
        message: orderMsg,
        orderNumber: s.orderNumber,
        payinAmount: payinAmount,
        payinCurrency: payinCurrency,
        payoutAmount: payoutAmount,
        payoutCurrency: payoutCurrency,
        exchangeRateAmount: s.exchangeRateAmount,
        exchangeRateCurrency: s.exchangeRateCurrency,
        payinMethod: payinMethodEnum,
        payoutMethod: payoutMethodEnum,
        orderStatus: orderStatusEnum,
        payinStatus: payinStatusEnum,
        payoutStatus: payoutStatusEnum,
        confirmationDeadline: confirmationDeadlineDt,
        createdAt: createdAtDt,
        scheduledPayoutTime: scheduledPayoutTimeDt,
        lightningInvoice: s.lightningInvoice,
        bitcoinAddress: s.bitcoinAddress,
        bitcoinTransactionId: s.bitcoinTransactionId,
        liquidAddress: s.liquidAddress,
        liquidTransactionId: s.liquidTransactionId,
        lightningAddress: s.lightningAddress,
        lnUrl: s.lnUrl,
        beneficiaryName: s.beneficiaryName,
        beneficiaryLabel: s.beneficiaryLabel,
        beneficiaryAccountNumber: s.beneficiaryAccountNumber,
        beneficiaryETransferAddress: s.beneficiaryETransferAddress,
        securityQuestion: s.securityQuestion,
        securityAnswer: s.securityAnswer,
        paymentDescription: s.paymentDescription,
        completedAt: completedAtDt,
        sentAt: sentAtDt,
        isPPBitcoinOutUpdatable: s.isPPBitcoinOutUpdatable,
        payinAmountChanged: payinAmountChangedObj,
        indexRateAmount: s.indexRateAmount,
        indexRateCurrency: s.indexRateCurrency,
        lightningVoucherExpiresAt: lightningVoucherExpiresAtDt,
        isTestnet: isTestnet,
      );
    case OrderType.refund:
      return Order.refund(
        orderId: s.orderId,
        orderType: orderTypeEnum,
        orderSubtype: s.orderSubtype,
        message: orderMsg,
        orderNumber: s.orderNumber,
        payinAmount: payinAmount,
        payinCurrency: payinCurrency,
        payoutAmount: payoutAmount,
        payoutCurrency: payoutCurrency,
        exchangeRateAmount: s.exchangeRateAmount,
        exchangeRateCurrency: s.exchangeRateCurrency,
        payinMethod: payinMethodEnum,
        payoutMethod: payoutMethodEnum,
        orderStatus: orderStatusEnum,
        payinStatus: payinStatusEnum,
        payoutStatus: payoutStatusEnum,
        confirmationDeadline: confirmationDeadlineDt,
        createdAt: createdAtDt,
        scheduledPayoutTime: scheduledPayoutTimeDt,
        beneficiaryName: s.beneficiaryName,
        beneficiaryLabel: s.beneficiaryLabel,
        beneficiaryAccountNumber: s.beneficiaryAccountNumber,
        beneficiaryETransferAddress: s.beneficiaryETransferAddress,
        securityQuestion: s.securityQuestion,
        securityAnswer: s.securityAnswer,
        paymentDescription: s.paymentDescription,
        completedAt: completedAtDt,
        sentAt: sentAtDt,
        isTestnet: isTestnet,
      );
    case OrderType.balanceAdjustment:
      return Order.balanceAdjustment(
        orderId: s.orderId,
        orderType: orderTypeEnum,
        orderSubtype: s.orderSubtype,
        message: orderMsg,
        orderNumber: s.orderNumber,
        payinAmount: payinAmount,
        payinCurrency: payinCurrency,
        payoutAmount: payoutAmount,
        payoutCurrency: payoutCurrency,
        exchangeRateAmount: s.exchangeRateAmount,
        exchangeRateCurrency: s.exchangeRateCurrency,
        payinMethod: payinMethodEnum,
        payoutMethod: payoutMethodEnum,
        orderStatus: orderStatusEnum,
        payinStatus: payinStatusEnum,
        payoutStatus: payoutStatusEnum,
        confirmationDeadline: confirmationDeadlineDt,
        createdAt: createdAtDt,
        scheduledPayoutTime: scheduledPayoutTimeDt,
        lnUrl: s.lnUrl,
        beneficiaryName: s.beneficiaryName,
        beneficiaryLabel: s.beneficiaryLabel,
        beneficiaryAccountNumber: s.beneficiaryAccountNumber,
        paymentDescription: s.paymentDescription,
        completedAt: completedAtDt,
        sentAt: sentAtDt,
        isTestnet: isTestnet,
      );
    case OrderType.sellUsdt:
    case OrderType.unknown:
      return Order.generic(
        orderId: s.orderId,
        orderType: orderTypeEnum,
        orderTypeName: s.orderType,
        orderSubtype: s.orderSubtype,
        message: orderMsg,
        orderNumber: s.orderNumber,
        payinAmount: payinAmount,
        payinCurrency: payinCurrency,
        payoutAmount: payoutAmount,
        payoutCurrency: payoutCurrency,
        exchangeRateAmount: s.exchangeRateAmount,
        exchangeRateCurrency: s.exchangeRateCurrency,
        payinMethod: payinMethodEnum,
        payoutMethod: payoutMethodEnum,
        orderStatus: orderStatusEnum,
        payinStatus: payinStatusEnum,
        payoutStatus: payoutStatusEnum,
        confirmationDeadline: confirmationDeadlineDt,
        createdAt: createdAtDt,
        scheduledPayoutTime: scheduledPayoutTimeDt,
        paymentDescription: s.paymentDescription,
        completedAt: completedAtDt,
        sentAt: sentAtDt,
        isTestnet: isTestnet,
      );
  }
}

DateTime? _tryParse(String? value) =>
    value == null ? null : DateTime.tryParse(value);
