import 'dart:typed_data';

import 'package:bb_mobile/_core/domain/entities/payjoin.dart';
import 'package:bb_mobile/_utils/uint_8_list_json_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pdk_payjoin_model.freezed.dart';
part 'pdk_payjoin_model.g.dart';

@freezed
sealed class PdkPayjoinModel with _$PdkPayjoinModel {
  const factory PdkPayjoinModel.receiver({
    required String id,
    required String receiver,
    required String walletId,
    required String pjUrl,
    required BigInt maxFeeRateSatPerVb,
    @Uint8ListJsonConverter() Uint8List? originalTxBytes,
    String? proposalPsbt,
    @Default(false) bool isExpired,
    @Default(false) bool isCompleted,
  }) = PdkPayjoinReceiverModel;
  const factory PdkPayjoinModel.sender({
    required String uri,
    required String sender,
    required String walletId,
    required String originalPsbt,
    String? proposalPsbt,
    String? txId,
    @Default(false) bool isExpired,
    @Default(false) bool isCompleted,
  }) = PdkPayjoinSenderModel;
  const PdkPayjoinModel._();

  factory PdkPayjoinModel.fromJson(Map<String, dynamic> json) =>
      _$PdkPayjoinModelFromJson(json);

  Payjoin toEntity() {
    final status = isCompleted
        ? PayjoinStatus.completed
        : isExpired
            ? PayjoinStatus.expired
            : proposalPsbt != null
                ? PayjoinStatus.proposed
                : PayjoinStatus.requested;
    return map(
      receiver: (model) => Payjoin.receiver(
        status: status,
        id: model.id,
        walletId: model.walletId,
        originalTxBytes: model.originalTxBytes,
        proposalPsbt: model.proposalPsbt,
      ),
      sender: (model) => Payjoin.sender(
        status: status,
        uri: model.uri,
        walletId: model.walletId,
        originalPsbt: model.originalPsbt,
        proposalPsbt: model.proposalPsbt,
        txId: model.txId,
      ),
    );
  }
}
