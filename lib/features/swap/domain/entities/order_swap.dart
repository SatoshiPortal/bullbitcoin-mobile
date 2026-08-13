import 'package:bb_mobile/features/swap/domain/entities/order_swap_network.dart';

class OrderSwap {
  final String orderId;
  final int orderNumber;
  final OrderSwapNetwork inNetwork;
  final OrderSwapNetwork outNetwork;
  final BigInt payinAmountSat;
  final BigInt payoutAmountSat;
  final String payinCurrency;
  final String payoutCurrency;
  final String payinMethod;
  final String payoutMethod;
  final String orderType;
  final String orderStatus;
  final String payinStatus;
  final String payoutStatus;
  final String messageCode;
  final String? bitcoinAddress;
  final String? liquidAddress;
  final String? lightningInvoice;
  final String? bitcoinTransactionId;
  final String? liquidTransactionId;
  final DateTime createdAt;
  final DateTime confirmationDeadline;
  final DateTime? completedAt;
  final DateTime? sentAt;

  OrderSwap({
    required this.orderId,
    required this.orderNumber,
    required this.inNetwork,
    required this.outNetwork,
    required this.payinAmountSat,
    required this.payoutAmountSat,
    required this.payinCurrency,
    required this.payoutCurrency,
    required this.payinMethod,
    required this.payoutMethod,
    required this.orderType,
    required this.orderStatus,
    required this.payinStatus,
    required this.payoutStatus,
    required this.messageCode,
    required this.createdAt,
    required this.confirmationDeadline,
    this.bitcoinAddress,
    this.liquidAddress,
    this.lightningInvoice,
    this.bitcoinTransactionId,
    this.liquidTransactionId,
    this.completedAt,
    this.sentAt,
  }) {
    if (orderId.isEmpty) throw ArgumentError('Order id cannot be empty');
    if (payinAmountSat <= BigInt.zero || payoutAmountSat <= BigInt.zero) {
      throw ArgumentError('Swap order amounts must be positive');
    }
    if (inNetwork == outNetwork) {
      throw ArgumentError('Swap order networks must differ');
    }
    if (!confirmationDeadline.isAfter(createdAt)) {
      throw ArgumentError('Confirmation deadline must follow creation');
    }
  }

  bool get isCompleted => orderStatus.toLowerCase() == 'completed';

  bool get isFundingOrder => orderType.toLowerCase() == 'funding';

  bool get requiresManualReview =>
      payinStatus.trim().toLowerCase() == 'under review';

  String get payinAddress =>
      payinAddressOrNull ??
      (throw StateError('Order has no payin address for ${inNetwork.name}'));

  /// Same as [payinAddress] but returns null instead of throwing when the
  /// address is not populated (e.g. legacy/partial server responses), so
  /// callers that only need to compare addresses can do so safely.
  String? get payinAddressOrNull => switch (inNetwork) {
    OrderSwapNetwork.bitcoin => bitcoinAddress,
    OrderSwapNetwork.liquid => liquidAddress,
    OrderSwapNetwork.lightning => lightningInvoice,
  };

  String? get payoutAddress => switch (outNetwork) {
    OrderSwapNetwork.bitcoin => bitcoinAddress,
    OrderSwapNetwork.liquid => liquidAddress,
    OrderSwapNetwork.lightning => lightningInvoice,
  };
}
