import 'package:bb_mobile/features/swap/domain/entities/order_swap.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_network.dart';

enum OrderSwapPurpose {
  transfer,
  sendLightning,
  receiveLightning,
  sendCrossChain,
  autoswap,
}

enum OrderSwapEnvironment { testnet, mainnet }

/// The maximum allowed deviation from the amount shown in the swap quote.
final class OrderSwapQuoteTolerance {
  const OrderSwapQuoteTolerance._();

  static BigInt forQuotedAmount(BigInt quotedAmountSat) {
    final percentage = quotedAmountSat ~/ BigInt.from(100);
    return percentage > BigInt.from(1000) ? percentage : BigInt.from(1000);
  }
}

enum OrderSwapLocalStatus {
  creating,
  creationUnknown,
  awaitingUserConfirmation,
  preparingPayin,
  readyToBroadcast,
  broadcastUnknown,
  payinBroadcast,
  payoutInProgress,
  completed,
  refunded,
  expired,
  failed;

  bool get isTerminal => switch (this) {
    completed || refunded || expired || failed => true,
    _ => false,
  };
}

class OrderSwapRecord {
  final String localId;
  final String? requestId;
  final OrderSwapPurpose purpose;
  final OrderSwapEnvironment environment;
  final OrderSwapNetwork inNetwork;
  final OrderSwapNetwork outNetwork;
  final bool isInAmountFixed;
  final BigInt requestedAmountSat;
  final BigInt? quotedCounterpartAmountSat;
  final String? sourceWalletId;
  final String? destinationWalletId;
  final String destination;
  final String fallback;
  final OrderSwap? order;
  final String? localPayinTransactionId;
  final String? signedPayinTransaction;
  final bool? payinIsPsbt;
  final DateTime createdAt;
  final OrderSwapLocalStatus localStatus;
  final DateTime? lastPolledAt;
  final String? note;
  final DateTime? labelsAppliedAt;

  OrderSwapRecord({
    required this.localId,
    required this.purpose,
    required this.environment,
    required this.inNetwork,
    required this.outNetwork,
    required this.isInAmountFixed,
    required this.requestedAmountSat,
    this.quotedCounterpartAmountSat,
    required this.destination,
    required this.fallback,
    required this.createdAt,
    required this.localStatus,
    this.sourceWalletId,
    this.destinationWalletId,
    this.requestId,
    this.order,
    this.localPayinTransactionId,
    this.signedPayinTransaction,
    this.payinIsPsbt,
    this.lastPolledAt,
    this.note,
    this.labelsAppliedAt,
  }) {
    if (localId.isEmpty) throw ArgumentError('Local id cannot be empty');
    if (requestId != null && requestId!.isEmpty) {
      throw ArgumentError('Request id cannot be empty');
    }
    if (requestedAmountSat <= BigInt.zero) {
      throw ArgumentError('Requested amount must be positive');
    }
    if (inNetwork == outNetwork) {
      throw ArgumentError('Swap order networks must differ');
    }
    if (destination.isEmpty) {
      throw ArgumentError('Destination cannot be empty');
    }
    if (fallback.isEmpty) throw ArgumentError('Fallback cannot be empty');
    if (order != null &&
        (order!.inNetwork != inNetwork || order!.outNetwork != outNetwork)) {
      throw ArgumentError('Server order networks do not match the request');
    }
    if (order != null &&
        (isInAmountFixed
            ? order!.payinAmountSat != requestedAmountSat
            : order!.payoutAmountSat != requestedAmountSat)) {
      throw ArgumentError('Server order does not preserve the fixed amount');
    }
    if (order != null && quotedCounterpartAmountSat != null) {
      final serverChosenAmount = isInAmountFixed
          ? order!.payoutAmountSat
          : order!.payinAmountSat;
      final deviation = (serverChosenAmount - quotedCounterpartAmountSat!)
          .abs();
      if (deviation >
          OrderSwapQuoteTolerance.forQuotedAmount(
            quotedCounterpartAmountSat!,
          )) {
        throw ArgumentError('Server order deviates too far from the quote');
      }
    }
    if (order == null &&
        localStatus != OrderSwapLocalStatus.creating &&
        localStatus != OrderSwapLocalStatus.creationUnknown &&
        localStatus != OrderSwapLocalStatus.failed) {
      throw ArgumentError('Server order is required for this local status');
    }
    if ((signedPayinTransaction == null) != (payinIsPsbt == null)) {
      throw ArgumentError('Signed payin transaction type is required');
    }
    if ((localStatus == OrderSwapLocalStatus.readyToBroadcast ||
            localStatus == OrderSwapLocalStatus.broadcastUnknown) &&
        signedPayinTransaction == null) {
      throw ArgumentError('Signed payin transaction is required for broadcast');
    }
    if (localStatus == OrderSwapLocalStatus.payinBroadcast &&
        localPayinTransactionId == null) {
      throw ArgumentError('Payin transaction id is required after broadcast');
    }
  }

  String? get orderId => order?.orderId;

  String? transactionIdForNetwork(OrderSwapNetwork network) =>
      switch (network) {
        OrderSwapNetwork.bitcoin => order?.bitcoinTransactionId,
        OrderSwapNetwork.liquid => order?.liquidTransactionId,
        OrderSwapNetwork.lightning => null,
      };

  String? get canonicalWalletId => sourceWalletId ?? destinationWalletId;

  OrderSwapNetwork? get canonicalWalletNetwork => sourceWalletId != null
      ? inNetwork
      : destinationWalletId != null
      ? outNetwork
      : null;

  String? get canonicalWalletTransactionId {
    if (sourceWalletId != null) {
      return localPayinTransactionId ?? transactionIdForNetwork(inNetwork);
    }
    return destinationWalletId == null
        ? null
        : transactionIdForNetwork(outNetwork);
  }

  String? get counterpartTransactionId {
    if (sourceWalletId != null) return transactionIdForNetwork(outNetwork);
    return destinationWalletId == null
        ? null
        : transactionIdForNetwork(inNetwork);
  }

  bool get hasPreparedPayin =>
      signedPayinTransaction != null && payinIsPsbt != null;

  OrderSwapRecord withServerOrder(
    OrderSwap serverOrder, {
    required OrderSwapLocalStatus status,
    DateTime? polledAt,
  }) => OrderSwapRecord(
    localId: localId,
    requestId: requestId,
    purpose: purpose,
    environment: environment,
    inNetwork: inNetwork,
    outNetwork: outNetwork,
    isInAmountFixed: isInAmountFixed,
    requestedAmountSat: requestedAmountSat,
    quotedCounterpartAmountSat: quotedCounterpartAmountSat,
    sourceWalletId: sourceWalletId,
    destinationWalletId: destinationWalletId,
    destination: destination,
    fallback: fallback,
    order: serverOrder,
    localPayinTransactionId: localPayinTransactionId,
    signedPayinTransaction: signedPayinTransaction,
    payinIsPsbt: payinIsPsbt,
    createdAt: createdAt,
    localStatus: status,
    lastPolledAt: polledAt ?? lastPolledAt,
    note: note,
    labelsAppliedAt: labelsAppliedAt,
  );

  OrderSwapRecord markCreationUnknown() => OrderSwapRecord(
    localId: localId,
    requestId: requestId,
    purpose: purpose,
    environment: environment,
    inNetwork: inNetwork,
    outNetwork: outNetwork,
    isInAmountFixed: isInAmountFixed,
    requestedAmountSat: requestedAmountSat,
    quotedCounterpartAmountSat: quotedCounterpartAmountSat,
    sourceWalletId: sourceWalletId,
    destinationWalletId: destinationWalletId,
    destination: destination,
    fallback: fallback,
    createdAt: createdAt,
    localStatus: OrderSwapLocalStatus.creationUnknown,
    note: note,
  );

  OrderSwapRecord markFailed() => OrderSwapRecord(
    localId: localId,
    requestId: requestId,
    purpose: purpose,
    environment: environment,
    inNetwork: inNetwork,
    outNetwork: outNetwork,
    isInAmountFixed: isInAmountFixed,
    requestedAmountSat: requestedAmountSat,
    quotedCounterpartAmountSat: quotedCounterpartAmountSat,
    sourceWalletId: sourceWalletId,
    destinationWalletId: destinationWalletId,
    destination: destination,
    fallback: fallback,
    createdAt: createdAt,
    localStatus: OrderSwapLocalStatus.failed,
    note: note,
  );

  OrderSwapRecord withPayinState({
    required OrderSwapLocalStatus status,
    String? signedTransaction,
    bool? isPsbt,
    String? transactionId,
  }) => OrderSwapRecord(
    localId: localId,
    requestId: requestId,
    purpose: purpose,
    environment: environment,
    inNetwork: inNetwork,
    outNetwork: outNetwork,
    isInAmountFixed: isInAmountFixed,
    requestedAmountSat: requestedAmountSat,
    quotedCounterpartAmountSat: quotedCounterpartAmountSat,
    sourceWalletId: sourceWalletId,
    destinationWalletId: destinationWalletId,
    destination: destination,
    fallback: fallback,
    order: order,
    localPayinTransactionId: transactionId ?? localPayinTransactionId,
    signedPayinTransaction: signedTransaction ?? signedPayinTransaction,
    payinIsPsbt: isPsbt ?? payinIsPsbt,
    createdAt: createdAt,
    localStatus: status,
    lastPolledAt: lastPolledAt,
    note: note,
    labelsAppliedAt: labelsAppliedAt,
  );

  OrderSwapRecord withLabelsAppliedAt(DateTime appliedAt) => OrderSwapRecord(
    localId: localId,
    requestId: requestId,
    purpose: purpose,
    environment: environment,
    inNetwork: inNetwork,
    outNetwork: outNetwork,
    isInAmountFixed: isInAmountFixed,
    requestedAmountSat: requestedAmountSat,
    quotedCounterpartAmountSat: quotedCounterpartAmountSat,
    sourceWalletId: sourceWalletId,
    destinationWalletId: destinationWalletId,
    destination: destination,
    fallback: fallback,
    order: order,
    localPayinTransactionId: localPayinTransactionId,
    signedPayinTransaction: signedPayinTransaction,
    payinIsPsbt: payinIsPsbt,
    createdAt: createdAt,
    localStatus: localStatus,
    lastPolledAt: lastPolledAt,
    note: note,
    labelsAppliedAt: appliedAt,
  );
}
