import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_domain_error.dart';
import 'package:meta/meta.dart';

@immutable
class FundingInstitution {
  final String _code;
  final String _name;

  const FundingInstitution._({required String code, required String name})
    : _code = code,
      _name = name;

  factory FundingInstitution.create({
    required String code,
    required String name,
  }) {
    if (code.trim().isEmpty) {
      throw const InvalidInstitutionCode();
    }
    if (name.trim().isEmpty) {
      throw const InvalidInstitutionName();
    }

    return FundingInstitution._(code: code.trim(), name: name.trim());
  }

  String get code => _code;
  String get name => _name;
}
