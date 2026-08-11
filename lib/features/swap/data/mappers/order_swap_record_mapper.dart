import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_network.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_record.dart';
import 'package:drift/drift.dart';

extension OrderSwapRecordToCompanionMapper on OrderSwapRecord {
  OrderSwapsCompanion toCompanion() => OrderSwapsCompanion.insert(
    localId: localId,
    requestId: Value(requestId),
    orderId: Value(order?.orderId),
    purpose: purpose.name,
    environment: environment.name,
    inNetwork: inNetwork.name,
    outNetwork: outNetwork.name,
    isInAmountFixed: isInAmountFixed,
    requestedAmountSat: _sqliteInt(requestedAmountSat),
    quotedAmountSat: Value(
      quotedCounterpartAmountSat == null
          ? null
          : _sqliteInt(quotedCounterpartAmountSat!),
    ),
    sourceWalletId: Value(sourceWalletId),
    destinationWalletId: Value(destinationWalletId),
    destination: destination,
    fallback: fallback,
    bitcoinAddress: Value(order?.bitcoinAddress),
    liquidAddress: Value(order?.liquidAddress),
    lightningInvoice: Value(order?.lightningInvoice),
    payinAmountSat: Value(
      order == null ? null : _sqliteInt(order!.payinAmountSat),
    ),
    payoutAmountSat: Value(
      order == null ? null : _sqliteInt(order!.payoutAmountSat),
    ),
    payinCurrency: Value(order?.payinCurrency),
    payoutCurrency: Value(order?.payoutCurrency),
    payinMethod: Value(order?.payinMethod),
    payoutMethod: Value(order?.payoutMethod),
    orderType: Value(order?.orderType),
    orderStatus: Value(order?.orderStatus),
    payinStatus: Value(order?.payinStatus),
    payoutStatus: Value(order?.payoutStatus),
    messageCode: Value(order?.messageCode),
    bitcoinTransactionId: Value(order?.bitcoinTransactionId),
    liquidTransactionId: Value(order?.liquidTransactionId),
    localPayinTransactionId: Value(localPayinTransactionId),
    signedPayinTransaction: Value(signedPayinTransaction),
    payinIsPsbt: Value(payinIsPsbt),
    orderNumber: Value(order?.orderNumber),
    createdAt: createdAt,
    serverCreatedAt: Value(order?.createdAt),
    confirmationDeadline: Value(order?.confirmationDeadline),
    sentAt: Value(order?.sentAt),
    localStatus: localStatus.name,
    lastPolledAt: Value(lastPolledAt),
    note: Value(note),
    serverCompletedAt: Value(order?.completedAt),
    labelsAppliedAt: Value(labelsAppliedAt),
  );
}

extension OrderSwapRowToEntityMapper on OrderSwapRow {
  OrderSwapRecord toEntity() => OrderSwapRecord(
    localId: localId,
    requestId: requestId,
    purpose: _byName(OrderSwapPurpose.values, purpose, 'purpose'),
    environment: _byName(
      OrderSwapEnvironment.values,
      environment,
      'environment',
    ),
    inNetwork: _byName(OrderSwapNetwork.values, inNetwork, 'inNetwork'),
    outNetwork: _byName(OrderSwapNetwork.values, outNetwork, 'outNetwork'),
    isInAmountFixed: isInAmountFixed,
    requestedAmountSat: BigInt.from(requestedAmountSat),
    quotedCounterpartAmountSat: quotedAmountSat == null
        ? null
        : BigInt.from(quotedAmountSat!),
    sourceWalletId: sourceWalletId,
    destinationWalletId: destinationWalletId,
    destination: destination,
    fallback: fallback,
    order: _serverOrder(),
    localPayinTransactionId: localPayinTransactionId,
    signedPayinTransaction: signedPayinTransaction,
    payinIsPsbt: payinIsPsbt,
    createdAt: createdAt.toUtc(),
    localStatus: _byName(
      OrderSwapLocalStatus.values,
      localStatus,
      'localStatus',
    ),
    lastPolledAt: lastPolledAt?.toUtc(),
    note: note,
    labelsAppliedAt: labelsAppliedAt?.toUtc(),
  );

  OrderSwap? _serverOrder() {
    if (orderId == null) return null;
    return OrderSwap(
      orderId: orderId!,
      orderNumber: _required(orderNumber, 'orderNumber'),
      inNetwork: _byName(OrderSwapNetwork.values, inNetwork, 'inNetwork'),
      outNetwork: _byName(OrderSwapNetwork.values, outNetwork, 'outNetwork'),
      payinAmountSat: BigInt.from(_required(payinAmountSat, 'payinAmountSat')),
      payoutAmountSat: BigInt.from(
        _required(payoutAmountSat, 'payoutAmountSat'),
      ),
      payinCurrency: _required(payinCurrency, 'payinCurrency'),
      payoutCurrency: _required(payoutCurrency, 'payoutCurrency'),
      payinMethod: _required(payinMethod, 'payinMethod'),
      payoutMethod: _required(payoutMethod, 'payoutMethod'),
      orderType: _required(orderType, 'orderType'),
      orderStatus: _required(orderStatus, 'orderStatus'),
      payinStatus: _required(payinStatus, 'payinStatus'),
      payoutStatus: _required(payoutStatus, 'payoutStatus'),
      messageCode: _required(messageCode, 'messageCode'),
      bitcoinAddress: bitcoinAddress,
      liquidAddress: liquidAddress,
      lightningInvoice: lightningInvoice,
      bitcoinTransactionId: bitcoinTransactionId,
      liquidTransactionId: liquidTransactionId,
      createdAt: _required(serverCreatedAt, 'serverCreatedAt').toUtc(),
      confirmationDeadline: _required(
        confirmationDeadline,
        'confirmationDeadline',
      ).toUtc(),
      completedAt: serverCompletedAt?.toUtc(),
      sentAt: sentAt?.toUtc(),
    );
  }
}

int _sqliteInt(BigInt value) {
  const max = 0x7fffffffffffffff;
  if (value < BigInt.zero || value > BigInt.from(max)) {
    throw ArgumentError.value(
      value,
      'value',
      'Must fit a signed SQLite integer',
    );
  }
  return value.toInt();
}

T _byName<T extends Enum>(Iterable<T> values, String name, String field) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw FormatException('Unknown $field: $name');
}

T _required<T>(T? value, String field) {
  if (value != null) return value;
  throw FormatException('Missing persisted $field');
}
