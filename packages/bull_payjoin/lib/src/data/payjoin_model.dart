import 'dart:typed_data';

import 'package:bull_payjoin/src/data/payjoin_database.dart';
import 'package:bull_payjoin/src/engine/payjoin.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'payjoin_model.freezed.dart';

@freezed
sealed class PayjoinModel with _$PayjoinModel {
  const factory PayjoinModel.receiver({
    required String id,
    required String address,
    required bool isTestnet,
    required String receiver,
    required String walletId,
    required String pjUri,
    required BigInt maxFeeRateSatPerVb,
    required int createdAt,
    required int expireAfterSec,
    @Default(false) bool isExchange,
    Uint8List? originalTxBytes,
    String? originalTxId,
    int? amountSat,
    String? proposalPsbt,
    String? txId,
    @Default(false) bool isExpired,
    @Default(false) bool isCompleted,
    @Default(false) bool isAborted,
  }) = PayjoinReceiverModel;
  const factory PayjoinModel.sender({
    required String uri,
    required bool isTestnet,
    required String sender,
    required String walletId,
    required String originalPsbt,
    required String originalTxId,
    required int amountSat,
    required int createdAt,
    required int expireAfterSec,
    @Default(false) bool isExchange,
    String? proposalPsbt,
    String? txId,
    @Default(false) bool isExpired,
    @Default(false) bool isCompleted,
    @Default(false) bool isAborted,
  }) = PayjoinSenderModel;
  const PayjoinModel._();

  // NOTE (fixed pre-existing bug): earlier versions of these factories never
  // mapped isExpired/isCompleted back from the row, so every re-fetch of a
  // session (app restart, transaction-details re-open, getPayjoins) silently
  // reset its displayed status to "never resolved" no matter what was
  // actually persisted. isAborted must be included here too, or the same
  // bug reappears for the new field the moment it's added.
  factory PayjoinModel.fromReceiverTable(PayjoinReceiverRow table) =>
      PayjoinReceiverModel(
        id: table.id,
        address: table.address,
        isTestnet: table.isTestnet,
        receiver: table.receiver,
        walletId: table.walletId,
        pjUri: table.pjUri,
        maxFeeRateSatPerVb: table.maxFeeRateSatPerVb,
        createdAt: table.createdAt,
        expireAfterSec: table.expireAfterSec,
        isExchange: table.isExchange,
        originalTxBytes: table.originalTxBytes,
        originalTxId: table.originalTxId,
        amountSat: table.amountSat,
        proposalPsbt: table.proposalPsbt,
        txId: table.txId,
        isExpired: table.isExpired,
        isCompleted: table.isCompleted,
        isAborted: table.isAborted,
      );

  factory PayjoinModel.fromSenderTable(PayjoinSenderRow table) =>
      PayjoinSenderModel(
        uri: table.uri,
        isTestnet: table.isTestnet,
        sender: table.sender,
        walletId: table.walletId,
        originalPsbt: table.originalPsbt,
        originalTxId: table.originalTxId,
        amountSat: table.amountSat,
        createdAt: table.createdAt,
        expireAfterSec: table.expireAfterSec,
        isExchange: table.isExchange,
        proposalPsbt: table.proposalPsbt,
        txId: table.txId,
        isExpired: table.isExpired,
        isCompleted: table.isCompleted,
        isAborted: table.isAborted,
      );

  int get expiresAt => createdAt + expireAfterSec;

  bool get isExpiryTimePassed =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 > expiresAt;

  String get id => switch (this) {
    PayjoinReceiverModel(:final id) => id,
    PayjoinSenderModel(:final uri) => uri,
  };

  // isCompleted (real payjoin broadcast) and isAborted (we broadcast the
  // original instead) are normally set on mutually exclusive paths, but
  // isCompleted is checked first regardless: the one path that can set both
  // is a genuine on-chain race where our payjoin transaction confirms after
  // the fallback watcher already marked the session aborted — see
  // PayjoinRepositoryImpl._broadcastPsbt, which logs that case. The real
  // payjoin is then the true outcome, so completed wins here.
  //
  // Note the txId is cleared when isAborted is set (see
  // _broadcastOriginalTransaction / _onOriginalTransactionSeen): that is
  // display hygiene (a stale, never-broadcast payjoin txid must not surface),
  // NOT how the status is derived — the status comes purely from these flags.
  PayjoinStatus get status => switch (this) {
    PayjoinReceiverModel(:final originalTxBytes) =>
      isCompleted
          ? PayjoinStatus.completed
          : isAborted
          ? PayjoinStatus.aborted
          : isExpired
          ? PayjoinStatus.expired
          : proposalPsbt != null
          ? PayjoinStatus.proposed
          : originalTxBytes != null
          ? PayjoinStatus.requested
          : PayjoinStatus.started,
    PayjoinSenderModel() =>
      isCompleted
          ? PayjoinStatus.completed
          : isAborted
          ? PayjoinStatus.aborted
          : isExpired
          ? PayjoinStatus.expired
          : proposalPsbt != null
          ? PayjoinStatus.proposed
          : PayjoinStatus.requested,
  };

  Payjoin toEntity() {
    switch (this) {
      case final PayjoinReceiverModel receiver:
        return Payjoin.receiver(
          status: status,
          id: id,
          isTestnet: receiver.isTestnet,
          pjUri: receiver.pjUri,
          createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
          expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000),
          walletId: walletId,
          isExchange: receiver.isExchange,
          originalTxBytes: receiver.originalTxBytes,
          originalTxId: originalTxId,
          amountSat: receiver.amountSat,
          proposalPsbt: proposalPsbt,
          txId: txId,
        );
      case final PayjoinSenderModel sender:
        return Payjoin.sender(
          status: status,
          uri: sender.uri,
          isTestnet: sender.isTestnet,
          createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
          expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000),
          walletId: walletId,
          isExchange: sender.isExchange,
          originalPsbt: sender.originalPsbt,
          originalTxId: sender.originalTxId,
          amountSat: sender.amountSat,
          proposalPsbt: proposalPsbt,
          txId: txId,
        );
    }
  }
}

extension PayjoinReceiverSqlite on PayjoinReceiverModel {
  PayjoinReceiverRow toSqlite() => PayjoinReceiverRow(
    id: id,
    address: address,
    isTestnet: isTestnet,
    receiver: receiver,
    walletId: walletId,
    pjUri: pjUri,
    maxFeeRateSatPerVb: maxFeeRateSatPerVb,
    createdAt: createdAt,
    expireAfterSec: expireAfterSec,
    isExchange: isExchange,
    originalTxBytes: originalTxBytes,
    originalTxId: originalTxId,
    amountSat: amountSat,
    proposalPsbt: proposalPsbt,
    txId: txId,
    isExpired: isExpired,
    isCompleted: isCompleted,
    isAborted: isAborted,
  );
}

extension PayjoinSenderSqlite on PayjoinSenderModel {
  PayjoinSenderRow toSqlite() => PayjoinSenderRow(
    uri: uri,
    isTestnet: isTestnet,
    sender: sender,
    walletId: walletId,
    originalPsbt: originalPsbt,
    originalTxId: originalTxId,
    amountSat: amountSat,
    createdAt: createdAt,
    expireAfterSec: expireAfterSec,
    isExchange: isExchange,
    proposalPsbt: proposalPsbt,
    txId: txId,
    isExpired: isExpired,
    isCompleted: isCompleted,
    isAborted: isAborted,
  );
}
