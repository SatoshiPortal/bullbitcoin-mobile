import 'package:bbx_api/src/bbx_api_exception.dart';
import 'package:bbx_api/src/json.dart';
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

  /// Throws a [BbxApiFormatException] naming the first invalid field.
  factory InstitutionAccountType.fromJson(Map<String, dynamic> json) =>
      InstitutionAccountType(
        code: read<String>(json['code'], 'code'),
        name: read<String>(json['name'], 'name'),
        minAddressLength: read<num>(
          json['minAddressLength'],
          'minAddressLength',
        ).toInt(),
        maxAddressLength: read<num>(
          json['maxAddressLength'],
          'maxAddressLength',
        ).toInt(),
      );
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

  /// Throws a [BbxApiFormatException] naming the first invalid field. The
  /// account types are also read from `accounTypes`, the server's misspelt
  /// key, when `accountTypes` is absent.
  factory Institution.fromJson(Map<String, dynamic> json) {
    final accountTypes = json.containsKey('accountTypes')
        ? json['accountTypes']
        : json['accounTypes'];
    return Institution(
      code: read<String>(json['code'], 'code'),
      name: read<String>(json['name'], 'name'),
      accountTypes: [
        for (final type in read<List<dynamic>>(accountTypes, 'accountTypes'))
          InstitutionAccountType.fromJson(
            read<Map<String, dynamic>>(type, 'accountTypes'),
          ),
      ],
    );
  }
}

/// The institutions of a country. An element that is not a valid
/// [Institution] is left out and counted in [skippedElements].
@immutable
class InstitutionList {
  final List<Institution> institutions;
  final int skippedElements;

  const InstitutionList({required this.institutions, this.skippedElements = 0});
}
