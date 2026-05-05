import 'package:nostr_pos/nostr_pos.dart' as nostr;

class PosSale {
  const PosSale({
    required this.saleId,
    required this.createdAt,
    required this.fiatCurrency,
    required this.fiatAmount,
    required this.satAmount,
    required this.status,
    required this.statusKind,
    this.method,
    this.methodKind,
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
  final nostr.SaleStatus statusKind;
  final String? method;
  final nostr.PosPaymentMethod? methodKind;
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
      status: summary.statusRaw,
      statusKind: summary.statusKind,
      method: summary.methodRaw,
      methodKind: summary.methodKind,
      settlementTxid: summary.settlementTxid,
      receiptId: summary.receiptId,
      note: summary.note,
    );
  }
}
