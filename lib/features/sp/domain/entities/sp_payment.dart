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
  /// Network proven when this history snapshot was loaded. Unknown is never
  /// sufficient to construct an explorer action.
  final BitcoinNetwork? network;
  final String txid;
  final SpPaymentDirection direction;
  final SpPaymentStatus status;
  final Sats amountSat;
  final Sats? feeSat;
  final int? height;
  final BigInt? timestamp;
  final bool hasSpOutput;

  SpPayment({
    this.network,
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

  /// Attach proven network provenance or the recomputed sub-account flag
  /// without changing transaction data from bwk.
  SpPayment copyWith({bool? hasSpOutput, BitcoinNetwork? network}) => SpPayment(
    network: network ?? this.network,
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
