import 'dart:typed_data';

import 'package:bb_mobile/_utils/uint_8_list_json_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pdk_payjoin_model.freezed.dart';
part 'pdk_payjoin_model.g.dart';

@freezed
sealed class PdkPayjoinModel with _$PdkPayjoinModel {
  const factory PdkPayjoinModel.receive({
    required String id,
    required String receiver,
    required String walletId,
    required String pjUrl,
    @Uint8ListJsonConverter() Uint8List? originalTxBytes,
    String? proposalPsbt,
  }) = PdkPayjoinReceiverModel;
  const factory PdkPayjoinModel.send({
    required String uri,
    required String sender,
    required String walletId,
    required String originalPsbt,
    String? proposalPsbt,
  }) = PdkPayjoinSenderModel;

  factory PdkPayjoinModel.fromJson(Map<String, dynamic> json) =>
      _$PdkPayjoinModelFromJson(json);
}
