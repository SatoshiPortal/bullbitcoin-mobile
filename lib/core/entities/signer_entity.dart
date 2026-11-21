import 'package:primitives/primitives.dart' show StringFormatting;

enum SignerEntity {
  local,
  remote,
  none;

  String get displayName =>
      StringFormatting.camelCaseToTitleCase(name, separator: ' ');
}
