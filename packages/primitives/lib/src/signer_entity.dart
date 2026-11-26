import 'string_formatting.dart';

enum SignerEntity {
  local,
  remote,
  none;

  String get displayName =>
      StringFormatting.camelCaseToTitleCase(name, separator: ' ');
}
