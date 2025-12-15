import 'package:bb_mobile/core_deprecated/utils/string_formatting.dart';

enum SignerEntity {
  local,
  remote,
  none;

  String get displayName =>
      StringFormatting.camelCaseToTitleCase(name, separator: ' ');
}
