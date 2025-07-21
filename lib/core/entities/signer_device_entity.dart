import 'package:bb_mobile/core/utils/string_formatting.dart';

enum SignerDeviceEntity {
  coldcardQ;

  String get displayName =>
      StringFormatting.camelCaseToTitleCase(name, separator: ' ');
}
