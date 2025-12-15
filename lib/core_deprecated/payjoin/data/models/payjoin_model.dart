import 'dart:typed_data';

import 'package:bb_mobile/core_deprecated/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/infra/database/sqlite_database.dart';
import 'package:bb_mobile/core_deprecated/utils/uint_8_list_json_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'payjoin_model.freezed.dart';
part 'payjoin_model.g.dart';

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
    @Uint8ListJsonConverter() Uint8List? originalTxBytes,
    String? originalTxId,
    int? amountSat,
    String? proposalPsbt,
    String? txId,
    @Default(false) bool isExpired,
    @Default(false) bool isCompleted,
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
    String? proposalPsbt,
    String? txId,
    @Default(false) bool isExpired,
    @Default(false) bool isCompleted,
  }) = PayjoinSenderModel;
  const PayjoinModel._();

  factory PayjoinModel.fromJson(Map<String, dynamic> json) =>
      _$PayjoinModelFromJson(json);

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
        originalTxBytes: table.originalTxBytes,
        originalTxId: table.originalTxId,
        amountSat: table.amountSat,
        proposalPsbt: table.proposalPsbt,
        txId: table.txId,
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
        proposalPsbt: table.proposalPsbt,
        txId: table.txId,
      );

  int get expiresAt => createdAt + expireAfterSec;

  bool get isExpiryTimePassed =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 > expiresAt;

  String get id => switch (this) {
    PayjoinReceiverModel(:final id) => id,
    PayjoinSenderModel(:final uri) => uri,
  };

  PayjoinStatus get status => switch (this) {
    PayjoinReceiverModel(:final originalTxBytes) =>
      isCompleted
          ? PayjoinStatus.completed
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
          : isExpired
          ? PayjoinStatus.expired
          : proposalPsbt != null
          ? PayjoinStatus.proposed
          : PayjoinStatus.requested,
  };

  bool get isOngoing =>
      status == PayjoinStatus.requested || status == PayjoinStatus.proposed;

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
    originalTxBytes: originalTxBytes,
    originalTxId: originalTxId,
    amountSat: amountSat,
    proposalPsbt: proposalPsbt,
    txId: txId,
    isExpired: isExpired,
    isCompleted: isCompleted,
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
    proposalPsbt: proposalPsbt,
    txId: txId,
    isExpired: isExpired,
    isCompleted: isCompleted,
  );
}
