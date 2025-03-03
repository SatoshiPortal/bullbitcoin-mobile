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
    String? originalPsbt,
    String? proposalPsbt,
  }) = PdkReceivePayjoinModel;
  const factory PdkPayjoinModel.send({
    required String uri,
    required String sender,
    required String walletId,
    required String originalPsbt,
    String? proposalPsbt,
  }) = PdkSendPayjoinModel;

  factory PdkPayjoinModel.fromJson(Map<String, dynamic> json) =>
      _$PdkPayjoinModelFromJson(json);
}
