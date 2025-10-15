import 'package:bb_mobile/core/utils/string_formatting.dart';

enum QrType { none, bbqr, urqr }

enum SignerDeviceEntity {
  coldcardQ,
  coldcardMk4,
  jade,
  keystone,
  krux,
  ledgerNanoSPlus,
  ledgerNanoX,
  ledgerFlex,
  ledgerStax,
  passport,
  seedsigner;

  String get displayName =>
      StringFormatting.camelCaseToTitleCase(name, separator: ' ');

  bool get isLedger => name.startsWith('ledger');

  bool get supportsBluetooth =>
      isLedger && this != SignerDeviceEntity.ledgerNanoSPlus;

  QrType get supportedQrType {
    switch (this) {
      case SignerDeviceEntity.coldcardQ:
        return QrType.bbqr;
      case SignerDeviceEntity.jade:
      case SignerDeviceEntity.krux:
      case SignerDeviceEntity.keystone:
      case SignerDeviceEntity.passport:
      case SignerDeviceEntity.seedsigner:
        return QrType.urqr;
      default:
        return QrType.none;
    }
  }
}
