import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/utils/string_formatting.dart';

enum SignerEntity {
  local,
  remote,
  none;

  Signer toModel() => switch (this) {
    SignerEntity.local => Signer.local,
    SignerEntity.remote => Signer.remote,
    SignerEntity.none => Signer.none,
  };

  String get displayName =>
      StringFormatting.camelCaseToTitleCase(name, separator: ' ');
}
