import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_institution.dart';
import 'package:bb_mobile/features/fund_exchange/adapters/funding_gateway/models/institution_account_type_model.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'institution_model.freezed.dart';
part 'institution_model.g.dart';

@freezed
sealed class InstitutionModel with _$InstitutionModel {
  const factory InstitutionModel({
    required String code,
    required String name,
    required List<InstitutionAccountTypeModel> accountTypes,
  }) = _InstitutionModel;

  // Handle backend typo 'accounTypes' until server-side fix is deployed
  factory InstitutionModel.fromJson(Map<String, dynamic> json) =>
      _$InstitutionModelFromJson(
        json.containsKey('accountTypes') || !json.containsKey('accounTypes')
            ? json
            : {...json, 'accountTypes': json['accounTypes']},
      );

  const InstitutionModel._();

  FundingInstitution get toDomain =>
      FundingInstitution.create(code: code, name: name);
}
