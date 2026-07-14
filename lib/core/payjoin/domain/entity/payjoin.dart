import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'payjoin.freezed.dart';

enum PayjoinStatus { started, requested, proposed, completed, expired }

@freezed
sealed class Payjoin with _$Payjoin {
  const factory Payjoin.receiver({
    @Default(PayjoinStatus.requested) PayjoinStatus status,
    required String id,
    required bool isTestnet,
    required String walletId,
    required String pjUri,
    required DateTime createdAt,
    required DateTime expiresAt,
    Uint8List? originalTxBytes,
    String? originalTxId,
    int? amountSat,
    String? proposalPsbt,
    String? txId,
  }) = PayjoinReceiver;
  const factory Payjoin.sender({
    @Default(PayjoinStatus.requested) PayjoinStatus status,
    required String uri,
    required bool isTestnet,
    required String walletId,
    required String originalPsbt,
    required String originalTxId,
    required int amountSat,
    required DateTime createdAt,
    required DateTime expiresAt,
    String? proposalPsbt,
    String? txId,
  }) = PayjoinSender;
  const Payjoin._();

  String get id => switch (this) {
    PayjoinReceiver(:final id) => id,
    PayjoinSender(:final uri) => uri,
  };

  /// Privacy-safe identifier for log lines. A sender's [id] IS the full
  /// BIP21 URI — address, amount and payjoin endpoint — which must never be
  /// logged (logs are user-shareable and SEVERE records reach Sentry). Hash
  /// it to the same opaque 16-hex-char shape as a receiver id, which is
  /// already a sha256 prefix of the pjUri and passes through unchanged so
  /// existing logs still correlate with stored sessions. The URI's `pj`/`rk`
  /// params make it high-entropy, so an unsalted hash is irreversible while
  /// staying stable across restarts (resumed-session logs keep correlating).
  String get logRef => switch (this) {
    PayjoinReceiver(:final id) => id,
    PayjoinSender(:final uri) =>
      sha256.convert(utf8.encode(uri)).toString().substring(0, 16),
  };

  bool get isCompleted => status == PayjoinStatus.completed;
  bool get isExpired => status == PayjoinStatus.expired;
  bool get isOngoing => !isCompleted && !isExpired;

  // Currently payjoin is always bitcoin, not liquid
  bool get isBitcoin => true;
  bool get isLiquid => false;
}
