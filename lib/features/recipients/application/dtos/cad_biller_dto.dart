import 'package:bb_mobile/features/recipients/domain/value_objects/cad_biller.dart';
import 'package:meta/meta.dart';

@immutable
class CadBillerDto {
  final String payeeCode;
  final String payeeName;

  const CadBillerDto({required this.payeeCode, required this.payeeName});

  // Domain → DTO
  factory CadBillerDto.fromDomain(CadBiller biller) {
    return CadBillerDto(
      payeeCode: biller.payeeCode,
      payeeName: biller.payeeName,
    );
  }

  // DTO → Domain
  CadBiller toDomain() {
    return CadBiller.create(payeeCode: payeeCode, payeeName: payeeName);
  }
}
