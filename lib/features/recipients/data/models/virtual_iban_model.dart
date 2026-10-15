import 'package:bb_mobile/features/recipients/domain/entities/virtual_iban.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'virtual_iban_model.freezed.dart';
part 'virtual_iban_model.g.dart';

@freezed
sealed class VirtualIbanModel with _$VirtualIbanModel {
  const factory VirtualIbanModel({
    String? iban,
    String? bicCode,
    String? bankAddress,
    String? ibanCountry,
  }) = _VirtualIbanModel;

  factory VirtualIbanModel.fromJson(Map<String, dynamic> json) =>
      _$VirtualIbanModelFromJson(json);

  const VirtualIbanModel._();

  VirtualIban get toDomain => VirtualIban.fromBankDetails(
    iban: iban,
    bicCode: bicCode,
    bankAddress: bankAddress,
    ibanCountry: ibanCountry,
  );
}
