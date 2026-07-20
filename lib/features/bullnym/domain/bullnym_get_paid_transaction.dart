import 'dart:convert';

import 'package:bb_mobile/features/bullnym/domain/bullnym_fiat_settlement.dart';

const int bullnymGetPaidTransactionMaxPageSize = 100;
const int bullnymGetPaidTransactionMaxCursorBytes = 256;
const int bullnymGetPaidTransactionMaxCommentBytes = 512;
const int bullnymGetPaidTransactionMaxReceivedAtUnix = 253402300799;

enum BullnymGetPaidTransactionSource {
  lightningAddress('lightning_address'),
  invoice('invoice'),
  paymentPage('payment_page'),
  pointOfSale('point_of_sale');

  final String wireValue;

  const BullnymGetPaidTransactionSource(this.wireValue);
}

enum BullnymGetPaidTransactionRail {
  lightning('lightning'),
  liquid('liquid'),
  bitcoin('bitcoin');

  final String wireValue;

  const BullnymGetPaidTransactionRail(this.wireValue);
}

enum BullnymGetPaidSettlementState {
  pending('pending'),
  settled('settled'),
  problem('problem');

  final String wireValue;

  const BullnymGetPaidSettlementState(this.wireValue);
}

/// One private, wallet-owned Get Paid receipt returned by Bullnym.
///
/// IDs remain internal navigation/deduplication keys. Presentation must not
/// expose them as user-facing transaction details.
class BullnymGetPaidTransaction {
  static final RegExp _canonicalUuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );
  static const String _nilUuid = '00000000-0000-0000-0000-000000000000';

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

  const BullnymGetPaidTransaction._({
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
  });

  factory BullnymGetPaidTransaction({
    required String transactionId,
    required BullnymGetPaidTransactionSource source,
    required String? invoiceId,
    required int amountSat,
    required int receivedAtUnix,
    required BullnymGetPaidTransactionRail rail,
    required BullnymGetPaidSettlementState settlementState,
    required bool late,
    required String? comment,
    BullnymGetPaidSettlement? settlement,
  }) {
    if (!_isCanonicalUuid(transactionId) ||
        amountSat <= 0 ||
        receivedAtUnix <= 0 ||
        receivedAtUnix > bullnymGetPaidTransactionMaxReceivedAtUnix) {
      throw ArgumentError('Invalid Bullnym Get Paid transaction');
    }
    if (source == BullnymGetPaidTransactionSource.lightningAddress) {
      if (invoiceId != null) {
        throw ArgumentError(
          'Lightning Address transaction cannot reference an invoice',
        );
      }
    } else if (invoiceId == null || !_isCanonicalUuid(invoiceId)) {
      throw ArgumentError('Invoice-backed transaction requires an invoice');
    }
    if (comment != null &&
        (comment.isEmpty ||
            comment.contains('\u0000') ||
            utf8.encode(comment).length >
                bullnymGetPaidTransactionMaxCommentBytes)) {
      throw ArgumentError('Invalid Bullnym Get Paid transaction comment');
    }
    return BullnymGetPaidTransaction._(
      transactionId: transactionId,
      source: source,
      invoiceId: invoiceId,
      amountSat: amountSat,
      receivedAtUnix: receivedAtUnix,
      rail: rail,
      settlementState: settlementState,
      late: late,
      comment: comment,
      settlement: settlement,
    );
  }

  static bool _isCanonicalUuid(String value) =>
      value != _nilUuid && _canonicalUuid.hasMatch(value);
}

class BullnymGetPaidTransactionPage {
  final List<BullnymGetPaidTransaction> transactions;
  final String? nextCursor;

  BullnymGetPaidTransactionPage({
    required List<BullnymGetPaidTransaction> transactions,
    required this.nextCursor,
  }) : transactions = List.unmodifiable(transactions) {
    final keys = <String>{};
    for (final transaction in transactions) {
      final key =
          '${transaction.source.wireValue}:${transaction.transactionId}';
      if (!keys.add(key)) {
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
