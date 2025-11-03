import 'package:bb_mobile/features/recipients/domain/value_objects/cad_biller.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'cad_biller_model.freezed.dart';
part 'cad_biller_model.g.dart';

/// MODEL: Gateway model for CAD biller API serialization/deserialization
/// Models are flat data containers that map directly to API responses
@freezed
class CadBillerModel with _$CadBillerModel {
  const factory CadBillerModel({
    required String payeeCode,
    required String payeeName,
  }) = _CadBillerModel;

  factory CadBillerModel.fromJson(Map<String, dynamic> json) =>
      _$CadBillerModelFromJson(json);

  const CadBillerModel._();

  /// Convert from model to domain value object
  CadBiller toValueObject() {
    return CadBiller(
      payeeCode: payeeCode,
      payeeName: payeeName,
    );
  }
}
