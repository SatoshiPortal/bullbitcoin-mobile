import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'payjoin.freezed.dart';

enum PayjoinStatus { started, requested, proposed, completed, expired }

@freezed
sealed class Payjoin with _$Payjoin {
  const factory Payjoin.receiver({
    @Default(PayjoinStatus.requested) PayjoinStatus status,
    required String id,
    required String walletId,
    required String pjUri,
    Uint8List? originalTxBytes,
    String? originalTxId,
    BigInt? amountSat,
    String? proposalPsbt,
    String? txId,
  }) = PayjoinReceiver;
  const factory Payjoin.sender({
    @Default(PayjoinStatus.requested) PayjoinStatus status,
    required String uri,
    required String walletId,
    required String originalPsbt,
    required String originalTxId,
    String? proposalPsbt,
    String? txId,
  }) = PayjoinSender;
  const Payjoin._();

  String get id => when(
        receiver: (_, id, __, ___, ____, _____, ______, _______, ________) =>
            id,
        sender: (_, uri, __, ___, ____, _____, ______) => uri,
      );

  bool get isCompleted => status == PayjoinStatus.completed;
  bool get isExpired => status == PayjoinStatus.expired;
}
