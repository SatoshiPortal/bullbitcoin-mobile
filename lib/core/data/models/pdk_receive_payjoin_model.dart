import 'package:freezed_annotation/freezed_annotation.dart';

part 'pdk_receive_payjoin_model.freezed.dart';
part 'pdk_receive_payjoin_model.g.dart';

@freezed
class PdkReceivePayjoinModel with _$PdkReceivePayjoinModel {
  const factory PdkReceivePayjoinModel({
    required String id,
    required String receiver,
    required String walletId,
    String? originalPsbt,
    String? proposalPsbt,
  }) = _PdkReceivePayjoinModel;
  const PdkReceivePayjoinModel._();

  factory PdkReceivePayjoinModel.fromJson(Map<String, dynamic> json) =>
      _$PdkReceivePayjoinModelFromJson(json);
}
