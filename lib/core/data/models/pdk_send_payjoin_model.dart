import 'package:freezed_annotation/freezed_annotation.dart';

part 'pdk_send_payjoin_model.freezed.dart';
part 'pdk_send_payjoin_model.g.dart';

@freezed
class PdkSendPayjoinModel with _$PdkSendPayjoinModel {
  const factory PdkSendPayjoinModel({
    required String uri,
    required String sender,
    required String walletId,
    required String originalPsbt,
    String? proposalPsbt,
  }) = _PdkSendPayjoinModel;
  const PdkSendPayjoinModel._();

  factory PdkSendPayjoinModel.fromJson(Map<String, dynamic> json) =>
      _$PdkSendPayjoinModelFromJson(json);
}
