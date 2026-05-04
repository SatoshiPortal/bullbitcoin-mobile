import 'package:nostr_pos/nostr_pos.dart' as nostr;

class PosSale {
  const PosSale({
    required this.saleId,
    required this.createdAt,
    required this.fiatCurrency,
    required this.fiatAmount,
    required this.satAmount,
    required this.status,
    this.method,
    this.settlementTxid,
    this.receiptId,
    this.note,
  });

  final String saleId;
  final DateTime createdAt;
  final String fiatCurrency;
  final String fiatAmount;
  final int satAmount;
  final String status;
  final String? method;
  final String? settlementTxid;
  final String? receiptId;
  final String? note;

  factory PosSale.fromSdk(nostr.SaleSummary summary) {
    return PosSale(
      saleId: summary.saleId,
      createdAt: DateTime.fromMillisecondsSinceEpoch(summary.createdAt * 1000),
      fiatCurrency: summary.fiatCurrency,
      fiatAmount: summary.fiatAmount,
      satAmount: summary.satAmount,
      status: summary.status,
      method: summary.method,
      settlementTxid: summary.settlementTxid,
      receiptId: summary.receiptId,
      note: summary.note,
    );
  }
}
