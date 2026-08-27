import 'dart:convert';

import 'package:bb_mobile/features/bullnym/domain/bullnym_fiat_settlement.dart';

const bullnymGetPaidTransactionMaxPageSize = 100;
const bullnymGetPaidTransactionMaxCursorBytes = 256;
const bullnymGetPaidTransactionMaxCommentBytes = 512;
const bullnymGetPaidTransactionMaxReceivedAtUnix = 253402300799;

enum BullnymGetPaidTransactionSource {
  lightningAddress('lightning_address'),
  invoice('invoice'),
  paymentPage('payment_page'),
  pointOfSale('point_of_sale');

  final String wireValue;

  const BullnymGetPaidTransactionSource(this.wireValue);

  static BullnymGetPaidTransactionSource? fromWire(String value) {
    for (final source in values) {
      if (source.wireValue == value) return source;
    }
    return null;
  }
}

enum BullnymGetPaidTransactionRail {
  lightning('lightning'),
  liquid('liquid'),
  bitcoin('bitcoin');

  final String wireValue;

  const BullnymGetPaidTransactionRail(this.wireValue);

  static BullnymGetPaidTransactionRail? fromWire(String value) {
    for (final rail in values) {
      if (rail.wireValue == value) return rail;
    }
    return null;
  }
}

enum BullnymGetPaidSettlementState {
  pending('pending'),
  settled('settled'),
  problem('problem');

  final String wireValue;

  const BullnymGetPaidSettlementState(this.wireValue);

  static BullnymGetPaidSettlementState? fromWire(String value) {
    for (final state in values) {
      if (state.wireValue == value) return state;
    }
    return null;
  }
}

final class BullnymGetPaidTransaction {
  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );
  static const _nilUuid = '00000000-0000-0000-0000-000000000000';

  final String transactionId;
  final BullnymGetPaidTransactionSource source;
  final String? invoiceId;
  final int amountSat;
  final int receivedAtUnix;
  final BullnymGetPaidTransactionRail rail;
  final BullnymGetPaidSettlementState settlementState;
  final bool late;
  final String? comment;
  final BullnymGetPaidSettlement? settlement;

  BullnymGetPaidTransaction({
    required this.transactionId,
    required this.source,
    required this.invoiceId,
    required this.amountSat,
    required this.receivedAtUnix,
    required this.rail,
    required this.settlementState,
    required this.late,
    required this.comment,
    required this.settlement,
  }) {
    if (!_validUuid(transactionId) ||
        amountSat <= 0 ||
        receivedAtUnix <= 0 ||
        receivedAtUnix > bullnymGetPaidTransactionMaxReceivedAtUnix ||
        (source == BullnymGetPaidTransactionSource.lightningAddress
            ? invoiceId != null
            : invoiceId == null || !_validUuid(invoiceId!)) ||
        (comment != null &&
            (comment!.isEmpty ||
                comment!.contains('\u0000') ||
                utf8.encode(comment!).length >
                    bullnymGetPaidTransactionMaxCommentBytes))) {
      throw ArgumentError('Invalid Bullnym Get Paid transaction');
    }
  }

  static bool _validUuid(String value) =>
      value != _nilUuid && _uuid.hasMatch(value);
}

final class BullnymGetPaidTransactionPage {
  final List<BullnymGetPaidTransaction> transactions;
  final String? nextCursor;

  BullnymGetPaidTransactionPage({
    required List<BullnymGetPaidTransaction> transactions,
    required this.nextCursor,
  }) : transactions = List.unmodifiable(transactions) {
    final keys = <String>{};
    for (final transaction in transactions) {
      if (!keys.add(
        '${transaction.source.wireValue}:${transaction.transactionId}',
      )) {
        throw ArgumentError('Duplicate Bullnym Get Paid transaction');
      }
    }
    if (nextCursor != null &&
        (nextCursor!.isEmpty ||
            nextCursor!.contains('\u0000') ||
            utf8.encode(nextCursor!).length >
                bullnymGetPaidTransactionMaxCursorBytes)) {
      throw ArgumentError('Invalid Bullnym Get Paid cursor');
    }
  }
}
