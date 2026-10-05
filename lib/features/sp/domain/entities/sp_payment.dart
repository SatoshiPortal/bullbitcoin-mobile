import 'package:primitives/primitives.dart';

/// Which way a payment moved, so the UI can label it without string-matching.
enum SpPaymentDirection { receive, send, selfSend }

enum SpPaymentStatus {
  unconfirmed,
  confirmedUnverified,
  verified,
  verifyFailed,
}

/// One entry in the Silent Payments payment history. Domain mirror of the bwk
/// `SpPaymentView` FFI struct; the wire type stays in `data/` behind
/// `SpPaymentMapper`.
class SpPayment {
  final String txid;
  final SpPaymentDirection direction;
  final SpPaymentStatus status;
  final Sats amountSat;
  final Sats? feeSat;
  final int? height;
  final BigInt? timestamp;
  final bool hasSpOutput;

  SpPayment({
    required this.txid,
    required this.direction,
    required this.status,
    required this.amountSat,
    this.feeSat,
    this.height,
    this.timestamp,
    this.hasSpOutput = false,
  }) {
    if (txid.isEmpty) {
      throw ArgumentError.value(txid, 'txid', 'must not be empty');
    }
    if (height != null && height! < 0) {
      throw ArgumentError.value(height, 'height', 'must not be negative');
    }
  }

  /// Only [hasSpOutput] is ever recomputed after mapping (the coin set says
  /// whether a payment landed on the SP sub-account), so that is the one field
  /// worth a copy. Everything else comes straight from bwk.
  SpPayment copyWith({bool? hasSpOutput}) => SpPayment(
    txid: txid,
    direction: direction,
    status: status,
    amountSat: amountSat,
    feeSat: feeSat,
    height: height,
    timestamp: timestamp,
    hasSpOutput: hasSpOutput ?? this.hasSpOutput,
  );
}
