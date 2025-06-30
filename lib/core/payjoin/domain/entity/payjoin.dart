import 'dart:typed_data';

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

  bool get isCompleted => status == PayjoinStatus.completed;
  bool get isExpired => status == PayjoinStatus.expired;
  bool get isOngoing => !isCompleted && !isExpired;

  // Currently payjoin is always bitcoin, not liquid
  bool get isBitcoin => true;
  bool get isLiquid => false;
}
