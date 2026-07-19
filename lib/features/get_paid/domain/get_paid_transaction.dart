import 'dart:convert';

enum GetPaidTransactionSource {
  lightningAddress,
  invoice,
  paymentPage,
  pointOfSale,
}

enum GetPaidTransactionRail { lightning, liquid, bitcoin }

enum GetPaidSettlementState { pending, settled, problem }

class GetPaidTransaction {
  static final RegExp _canonicalUuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );
  static const String _nilUuid = '00000000-0000-0000-0000-000000000000';
  static const int _maxCommentBytes = 512;

  final String transactionId;
  final GetPaidTransactionSource source;
  final String? invoiceId;
  final int amountSat;
  final DateTime receivedAt;
  final GetPaidTransactionRail rail;
  final GetPaidSettlementState settlementState;
  final bool late;
  final String? comment;

  const GetPaidTransaction._({
    required this.transactionId,
    required this.source,
    required this.invoiceId,
    required this.amountSat,
    required this.receivedAt,
    required this.rail,
    required this.settlementState,
    required this.late,
    required this.comment,
  });

  factory GetPaidTransaction({
    required String transactionId,
    required GetPaidTransactionSource source,
    required String? invoiceId,
    required int amountSat,
    required DateTime receivedAt,
    required GetPaidTransactionRail rail,
    required GetPaidSettlementState settlementState,
    required bool late,
    required String? comment,
  }) {
    if (!_isCanonicalUuid(transactionId) ||
        amountSat <= 0 ||
        receivedAt.millisecondsSinceEpoch <= 0) {
      throw ArgumentError('Invalid Get Paid transaction');
    }
    if (source == GetPaidTransactionSource.lightningAddress &&
        invoiceId != null) {
      throw ArgumentError('Lightning Address receipt cannot have invoice id');
    }
    if (source != GetPaidTransactionSource.lightningAddress &&
        (invoiceId == null || !_isCanonicalUuid(invoiceId))) {
      throw ArgumentError('Invoice-backed receipt requires invoice id');
    }
    if (comment != null &&
        (comment.isEmpty ||
            comment.contains('\u0000') ||
            utf8.encode(comment).length > _maxCommentBytes)) {
      throw ArgumentError('Invalid Get Paid transaction comment');
    }
    return GetPaidTransaction._(
      transactionId: transactionId,
      source: source,
      invoiceId: invoiceId,
      amountSat: amountSat,
      receivedAt: receivedAt.toUtc(),
      rail: rail,
      settlementState: settlementState,
      late: late,
      comment: comment,
    );
  }

  String get stableKey => '${source.name}:$transactionId';

  bool get isInvoiceBacked => invoiceId != null;

  static bool _isCanonicalUuid(String value) =>
      value != _nilUuid && _canonicalUuid.hasMatch(value);
}

class GetPaidTransactionPage {
  final List<GetPaidTransaction> transactions;
  final String? nextCursor;

  GetPaidTransactionPage({
    required List<GetPaidTransaction> transactions,
    required this.nextCursor,
  }) : transactions = List.unmodifiable(transactions);
}
