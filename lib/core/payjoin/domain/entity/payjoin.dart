import 'dart:typed_data';

import 'package:bb_mobile/core/utils/transaction_parsing.dart';
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
    String? proposalPsbt,
    String? txId,
  }) = PayjoinReceiver;
  const factory Payjoin.sender({
    @Default(PayjoinStatus.requested) PayjoinStatus status,
    required String uri,
    required String walletId,
    required String originalPsbt,
    String? proposalPsbt,
    String? txId,
  }) = PayjoinSender;
  const Payjoin._();

  String get id => when(
        receiver: (_, id, __, ___, ____, _____, ______) => id,
        sender: (_, uri, __, ___, ____, _____) => uri,
      );

  Future<bool> get isOriginalTxBroadcasted async {
    if (txId == null) {
      return false;
    }

    String originalTxId;
    switch (this) {
      case final PayjoinReceiver receiver:
        if (receiver.originalTxBytes == null) {
          return false;
        }
        originalTxId = await TransactionParsing.getTxIdFromTransactionBytes(
          receiver.originalTxBytes!,
        );
      case final PayjoinSender sender:
        originalTxId = await TransactionParsing.getTxIdFromPsbt(
          sender.originalPsbt,
        );
    }

    return txId == originalTxId;
  }

  Future<bool> get isPayjoinTxBroadcasted async {
    if (txId == null) {
      return false;
    }

    String payjoinTxId;
    switch (this) {
      case final PayjoinReceiver receiver:
        if (receiver.proposalPsbt == null) {
          return false;
        }
        payjoinTxId = await TransactionParsing.getTxIdFromPsbt(
          receiver.proposalPsbt!,
        );
      case final PayjoinSender sender:
        if (sender.proposalPsbt == null) {
          return false;
        }
        payjoinTxId = await TransactionParsing.getTxIdFromPsbt(
          sender.proposalPsbt!,
        );
    }

    return txId == payjoinTxId;
  }

  bool get isCompleted => status == PayjoinStatus.completed;
  bool get isExpired => status == PayjoinStatus.expired;
}
