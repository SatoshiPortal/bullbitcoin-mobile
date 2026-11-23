import 'package:bbx_api/src/bbx_failure.dart';
import 'package:meta/meta.dart';

/// An order as `api-orders` returns it, with the server's raw values: types,
/// statuses and methods are the server's strings and dates are unparsed.
///
/// Admin-initiated orders (reward, funding, refund, balance adjustment) have
/// no real pay-in side, so amounts, currencies, statuses and methods may be
/// missing.
@immutable
class OrderSummary {
  final String orderId;

  /// For example `Buy Bitcoin`.
  final String orderType;
  final String? orderSubtype;
  final int orderNumber;
  final double? exchangeRateAmount;
  final String? exchangeRateCurrency;
  final double? indexRateAmount;
  final String? indexRateCurrency;
  final double? payinAmount;
  final String? payinCurrency;
  final double? payoutAmount;
  final String? payoutCurrency;
  final String? orderStatus;
  final String? payinStatus;
  final String? payoutStatus;
  final String? scheduledPayoutTime;
  final String createdAt;
  final String? completedAt;
  final OrderMessage? message;
  final String? sentAt;
  final String? payinMethod;
  final String? payoutMethod;
  final String? triggerType;
  final String? confirmationDeadline;
  final String? bitcoinTransactionId;
  final String? lnUrl;
  final String? lightningVoucherExpiresAt;
  final bool? isPPBitcoinOutUpdatable;
  final OrderPayinAmountChanged? payinAmountChanged;
  final String? lightningInvoice;
  final String? bitcoinAddress;
  final String? liquidAddress;
  final String? liquidTransactionId;
  final String? lightningAddress;
  final String? beneficiaryName;
  final String? beneficiaryLabel;
  final String? beneficiaryAccountNumber;
  final String? beneficiaryETransferAddress;
  final String? securityQuestion;
  final String? securityAnswer;
  final String? paymentDescription;
  final double? unbatchedBuyOnchainFees;

  /// The payjoin BIP21 URI, verbatim.
  final String? bip21URI;
  final OrderPayjoinDetails? payjoinDetails;
  final String? referenceNumber;
  final String? originName;
  final String? originCedula;

  const OrderSummary({
    required this.orderId,
    required this.orderType,
    this.orderSubtype,
    required this.orderNumber,
    this.exchangeRateAmount,
    this.exchangeRateCurrency,
    this.indexRateAmount,
    this.indexRateCurrency,
    this.payinAmount,
    this.payinCurrency,
    this.payoutAmount,
    this.payoutCurrency,
    this.orderStatus,
    this.payinStatus,
    this.payoutStatus,
    this.scheduledPayoutTime,
    required this.createdAt,
    this.completedAt,
    this.message,
    this.sentAt,
    this.payinMethod,
    this.payoutMethod,
    this.triggerType,
    this.confirmationDeadline,
    this.bitcoinTransactionId,
    this.lnUrl,
    this.lightningVoucherExpiresAt,
    this.isPPBitcoinOutUpdatable,
    this.payinAmountChanged,
    this.lightningInvoice,
    this.bitcoinAddress,
    this.liquidAddress,
    this.liquidTransactionId,
    this.lightningAddress,
    this.beneficiaryName,
    this.beneficiaryLabel,
    this.beneficiaryAccountNumber,
    this.beneficiaryETransferAddress,
    this.securityQuestion,
    this.securityAnswer,
    this.paymentDescription,
    this.unbatchedBuyOnchainFees,
    this.bip21URI,
    this.payjoinDetails,
    this.referenceNumber,
    this.originName,
    this.originCedula,
  });
}

/// The server's note on an order. Non-string values are kept as their
/// `toString()`.
@immutable
class OrderMessage {
  final String? code;
  final String? message;

  const OrderMessage({this.code, this.message});
}

/// Set when the received pay-in differs from the requested amount.
@immutable
class OrderPayinAmountChanged {
  final double? requestedAmount;
  final double? receivedAmount;

  const OrderPayinAmountChanged({this.requestedAmount, this.receivedAmount});
}

/// The payjoin state of an order. Only the transaction id is read.
@immutable
class OrderPayjoinDetails {
  /// `null` until the exchange has seen the payjoin transaction.
  final String? txid;

  const OrderPayjoinDetails({this.txid});
}

/// One page of `listOrderSummaries`.
///
/// An element that cannot be read is left out of [orders] and its error is
/// kept in [rejected], so one malformed order does not cost the whole list.
@immutable
class OrderSummaryList {
  final List<OrderSummary> orders;
  final List<BbxResponseFormatFailure> rejected;

  const OrderSummaryList({required this.orders, this.rejected = const []});
}
