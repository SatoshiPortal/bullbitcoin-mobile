import 'package:meta/meta.dart';

/// An account type an [Institution] offers.
@immutable
class InstitutionAccountType {
  final String code;
  final String name;
  final int minAddressLength;
  final int maxAddressLength;

  const InstitutionAccountType({
    required this.code,
    required this.name,
    required this.minAddressLength,
    required this.maxAddressLength,
  });
}

/// A bank from `listInstitutionCodes`.
@immutable
class Institution {
  final String code;
  final String name;
  final List<InstitutionAccountType> accountTypes;

  const Institution({
    required this.code,
    required this.name,
    required this.accountTypes,
  });
}

/// The institutions of a country. An element that is not a valid
/// [Institution] is left out and counted in [skippedElements].
@immutable
class InstitutionList {
  final List<Institution> institutions;
  final int skippedElements;

  const InstitutionList({required this.institutions, this.skippedElements = 0});
}
