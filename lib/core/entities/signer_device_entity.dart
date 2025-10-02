import 'package:bb_mobile/core/utils/string_formatting.dart';

enum SignerDeviceEntity {
  coldcardQ,
  ledgerNanoSPlus,
  ledgerNanoX,
  ledgerFlex,
  ledgerStax;

  String get displayName =>
      StringFormatting.camelCaseToTitleCase(name, separator: ' ');

  bool get isLedger => name.startsWith('ledger');

  bool get supportsBluetooth =>
      isLedger && this != SignerDeviceEntity.ledgerNanoSPlus;
}
