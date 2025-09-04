import 'package:bb_mobile/core/exchange/domain/entity/cad_biller.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'cad_biller_model.freezed.dart';
part 'cad_biller_model.g.dart';

@freezed
sealed class CadBillerModel with _$CadBillerModel {
  const factory CadBillerModel({
    required String payeeCode,
    required String payeeName,
  }) = _CadBillerModel;

  factory CadBillerModel.fromJson(Map<String, dynamic> json) =>
      _$CadBillerModelFromJson(json);

  const CadBillerModel._();

  CadBiller toEntity() {
    return CadBiller(payeeCode: payeeCode, payeeName: payeeName);
  }
}
