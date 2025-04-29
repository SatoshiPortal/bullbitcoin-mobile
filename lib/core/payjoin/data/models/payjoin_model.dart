import 'dart:typed_data';

import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/utils/uint_8_list_json_converter.dart';
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
    @Default(0) int expireAt,
    @Uint8ListJsonConverter() Uint8List? originalTxBytes,
    String? originalTxId,
    BigInt? amountSat,
    String? proposalPsbt,
    String? txId,
    @Default(false) bool isExpired,
    @Default(false) bool isCompleted,
  }) = PayjoinReceiverModel;
  const factory PayjoinModel.sender({
    required String uri,
    required String sender,
    required String walletId,
    required String originalPsbt,
    required String originalTxId,
    @Default(0) int expireAt,
    String? proposalPsbt,
    String? txId,
    @Default(false) bool isExpired,
    @Default(false) bool isCompleted,
  }) = PayjoinSenderModel;
  const PayjoinModel._();

  factory PayjoinModel.fromJson(Map<String, dynamic> json) =>
      _$PayjoinModelFromJson(json);

  bool get isExpireAtPassed =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 > expireAt;

  String get id => switch (this) {
    PayjoinReceiverModel(:final id) => id,
    PayjoinSenderModel(:final uri) => uri,
  };

  Payjoin toEntity() {
    return switch (this) {
      PayjoinReceiverModel(
        :final id,
        :final pjUri,
        :final walletId,
        :final originalTxBytes,
        :final originalTxId,
        :final amountSat,
        :final proposalPsbt,
        :final txId,
        :final isCompleted,
        :final isExpired,
      ) =>
        Payjoin.receiver(
          status:
              isCompleted
                  ? PayjoinStatus.completed
                  : isExpired
                  ? PayjoinStatus.expired
                  : proposalPsbt != null
                  ? PayjoinStatus.proposed
                  : originalTxBytes != null
                  ? PayjoinStatus.requested
                  : PayjoinStatus.started,
          id: id,
          pjUri: pjUri,
          walletId: walletId,
          originalTxBytes: originalTxBytes,
          originalTxId: originalTxId,
          amountSat: amountSat,
          proposalPsbt: proposalPsbt,
          txId: txId,
        ),
      PayjoinSenderModel(
        :final uri,
        :final walletId,
        :final originalPsbt,
        :final originalTxId,
        :final proposalPsbt,
        :final txId,
        :final isCompleted,
        :final isExpired,
      ) =>
        Payjoin.sender(
          status:
              isCompleted
                  ? PayjoinStatus.completed
                  : isExpired
                  ? PayjoinStatus.expired
                  : proposalPsbt != null
                  ? PayjoinStatus.proposed
                  : PayjoinStatus.requested,
          uri: uri,
          walletId: walletId,
          originalPsbt: originalPsbt,
          originalTxId: originalTxId,
          proposalPsbt: proposalPsbt,
          txId: txId,
        ),
    };
  }
}
