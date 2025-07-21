import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/utils/string_formatting.dart';

enum SignerDeviceEntity {
  coldcardQ;

  SignerDevice toModel() => switch (this) {
    SignerDeviceEntity.coldcardQ => SignerDevice.coldcardQ,
  };

  String get displayName =>
      StringFormatting.camelCaseToTitleCase(name, separator: ' ');
}
