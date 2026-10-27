import 'package:meta/meta.dart';

@immutable
class FundingInstitution {
  final String _code;
  final String _name;

  const FundingInstitution._({required this._code, required this._name});

  /// Throws [ArgumentError] on a blank code or name. That is a malformed API
  /// payload, caught per element where institutions are parsed — never a
  /// modeled failure the user can act on.
  factory FundingInstitution.create({
    required String code,
    required String name,
  }) {
    if (code.trim().isEmpty) {
      throw ArgumentError.value(code, 'code', 'Institution code is empty');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Institution name is empty');
    }

    return FundingInstitution._(code: code.trim(), name: name.trim());
  }

  String get code => _code;
  String get name => _name;
}
