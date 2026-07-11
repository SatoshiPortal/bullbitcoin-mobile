/// Which way a payment moved, so the UI can label it without string-matching.
enum SpPaymentDirection { receive, send, selfSend }

/// One entry in the Silent Payments payment history. Domain mirror of the bwk
/// `SpPaymentView` FFI struct; the wire type stays in `data/` behind
/// `SpPaymentMapper`.
class SpPayment {
  final String txid;
  final SpPaymentDirection direction;
  final BigInt amountSat;
  final BigInt? feeSat;
  final int? height;
  final BigInt? timestamp;
  final String? label;

  const SpPayment({
    required this.txid,
    required this.direction,
    required this.amountSat,
    this.feeSat,
    this.height,
    this.timestamp,
    this.label,
  });
}
