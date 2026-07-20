import 'package:bb_mobile/features/bullnym/domain/bullnym_fiat_settlement.dart';

final class BullnymGetPaidTransactionModel {
  final String transactionId;
  final String source;
  final String? invoiceId;
  final int amountSat;
  final int receivedAtUnix;
  final String rail;
  final String settlementState;
  final bool late;
  final String? comment;

  /// Optional private settlement projection; parsed tolerantly so unknown
  /// shapes never fail the whole page (they surface as "unavailable").
  final BullnymGetPaidSettlement? settlement;

  const BullnymGetPaidTransactionModel({
    required this.transactionId,
    required this.source,
    required this.invoiceId,
    required this.amountSat,
    required this.receivedAtUnix,
    required this.rail,
    required this.settlementState,
    required this.late,
    required this.comment,
    this.settlement,
  });

  factory BullnymGetPaidTransactionModel.fromJson(Map<String, dynamic> json) {
    return BullnymGetPaidTransactionModel(
      transactionId: _requiredString(json, 'transaction_id'),
      source: _requiredString(json, 'source'),
      invoiceId: _optionalString(json, 'invoice_id'),
      amountSat: _requiredInt(json, 'amount_sat'),
      receivedAtUnix: _requiredInt(json, 'received_at_unix'),
      rail: _requiredString(json, 'rail'),
      settlementState: _requiredString(json, 'settlement_state'),
      late: _requiredBool(json, 'late'),
      comment: _optionalString(json, 'comment'),
      settlement: BullnymGetPaidSettlement.tryParse(json),
    );
  }
}

final class BullnymGetPaidTransactionPageModel {
  final List<BullnymGetPaidTransactionModel> transactions;
  final String? nextCursor;

  BullnymGetPaidTransactionPageModel({
    required List<BullnymGetPaidTransactionModel> transactions,
    required this.nextCursor,
  }) : transactions = List.unmodifiable(transactions);

  factory BullnymGetPaidTransactionPageModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawTransactions = json['transactions'];
    if (rawTransactions is! List<dynamic>) {
      throw const FormatException('Missing transactions list');
    }
    return BullnymGetPaidTransactionPageModel(
      transactions: rawTransactions
          .map((raw) {
            if (raw is! Map<String, dynamic>) {
              throw const FormatException('Invalid transaction item');
            }
            return BullnymGetPaidTransactionModel.fromJson(raw);
          })
          .toList(growable: false),
      nextCursor: _optionalString(json, 'next_cursor'),
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Missing string field $key');
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('Invalid string field $key');
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('Missing int field $key');
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw FormatException('Missing bool field $key');
}
