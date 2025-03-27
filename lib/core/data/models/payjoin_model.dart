import 'dart:typed_data';

import 'package:bb_mobile/core/domain/entities/payjoin.dart';
import 'package:bb_mobile/core/utils/uint_8_list_json_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'payjoin_model.freezed.dart';
part 'payjoin_model.g.dart';

@freezed
sealed class PayjoinModel with _$PayjoinModel {
  const factory PayjoinModel.receiver({
    required String id,
    required String receiver,
    required String walletId,
    required String pjUri,
    required BigInt maxFeeRateSatPerVb,
    @Uint8ListJsonConverter() Uint8List? originalTxBytes,
    String? proposalPsbt,
    @Default(false) bool isExpired,
    @Default(false) bool isCompleted,
  }) = PayjoinReceiverModel;
  const factory PayjoinModel.sender({
    required String uri,
    required String sender,
    required String walletId,
    required String originalPsbt,
    String? proposalPsbt,
    String? txId,
    @Default(false) bool isExpired,
    @Default(false) bool isCompleted,
  }) = PayjoinSenderModel;
  const PayjoinModel._();

  factory PayjoinModel.fromJson(Map<String, dynamic> json) =>
      _$PayjoinModelFromJson(json);

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
        walletId: model.walletId,
        originalTxBytes: model.originalTxBytes,
        proposalPsbt: model.proposalPsbt,
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
        walletId: model.walletId,
        originalPsbt: model.originalPsbt,
        proposalPsbt: model.proposalPsbt,
        txId: model.txId,
      ),
    );
  }
}
