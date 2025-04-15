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
    required String origin,
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
    required String origin,
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

  Payjoin toEntity() {
    return map(
      receiver: (model) => Payjoin.receiver(
        status: isCompleted
            ? PayjoinStatus.completed
            : isExpired
                ? PayjoinStatus.expired
                : proposalPsbt != null
                    ? PayjoinStatus.proposed
                    : model.originalTxBytes != null
                        ? PayjoinStatus.requested
                        : PayjoinStatus.started,
        id: model.id,
        pjUri: model.pjUri,
        origin: model.origin,
        originalTxBytes: model.originalTxBytes,
        originalTxId: model.originalTxId,
        amountSat: model.amountSat,
        proposalPsbt: model.proposalPsbt,
        txId: model.txId,
      ),
      sender: (model) => Payjoin.sender(
        status: isCompleted
            ? PayjoinStatus.completed
            : isExpired
                ? PayjoinStatus.expired
                : proposalPsbt != null
                    ? PayjoinStatus.proposed
                    : PayjoinStatus.requested,
        uri: model.uri,
        origin: model.origin,
        originalPsbt: model.originalPsbt,
        originalTxId: model.originalTxId,
        proposalPsbt: model.proposalPsbt,
        txId: model.txId,
      ),
    );
  }
}
