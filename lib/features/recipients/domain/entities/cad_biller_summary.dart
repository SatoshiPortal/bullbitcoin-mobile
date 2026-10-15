import 'package:bb_mobile/features/recipients/domain/entities/cad_biller.dart';
import 'package:meta/meta.dart';

@immutable
class CadBillerSummary {
  final String payeeCode;
  final String payeeName;

  const CadBillerSummary({required this.payeeCode, required this.payeeName});

  // Domain → Summary
  factory CadBillerSummary.fromDomain(CadBiller biller) {
    return CadBillerSummary(
      payeeCode: biller.payeeCode,
      payeeName: biller.payeeName,
    );
  }

  // Summary → Domain
  CadBiller toDomain() {
    return CadBiller.create(payeeCode: payeeCode, payeeName: payeeName);
  }
}
