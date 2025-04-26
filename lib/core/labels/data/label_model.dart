import 'package:freezed_annotation/freezed_annotation.dart';

part 'label_model.freezed.dart';
part 'label_model.g.dart';

@freezed
sealed class LabelModel with _$LabelModel {
  factory LabelModel({
    required String type,
    required String ref,
    required String label,
    String? origin,
    bool? spendable,
  }) = _LabelModel;
  const LabelModel._();

  factory LabelModel.fromJson(Map<String, dynamic> json) =>
      _$LabelModelFromJson(json);
}
