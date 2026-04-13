import 'package:freezed_annotation/freezed_annotation.dart';

part 'institution_account_type_model.freezed.dart';
part 'institution_account_type_model.g.dart';

@freezed
sealed class InstitutionAccountTypeModel
    with _$InstitutionAccountTypeModel {
  const factory InstitutionAccountTypeModel({
    required String code,
    required String name,
    required int minAddressLength,
    required int maxAddressLength,
  }) = _InstitutionAccountTypeModel;

  factory InstitutionAccountTypeModel.fromJson(
    Map<String, dynamic> json,
  ) => _$InstitutionAccountTypeModelFromJson(json);

  const InstitutionAccountTypeModel._();
}
