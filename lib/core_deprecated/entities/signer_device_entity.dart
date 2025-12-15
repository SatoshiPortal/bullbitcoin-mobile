import 'package:bb_mobile/core_deprecated/utils/string_formatting.dart';

enum QrType { none, bbqr, urqr }

enum SignerDeviceEntity {
  bitbox02,
  coldcardQ,
  jade,
  keystone,
  krux,
  ledgerNanoSPlus,
  ledgerNanoX,
  ledgerFlex,
  ledgerStax,
  passport,
  seedsigner,
  specter;

  String get displayName =>
      StringFormatting.camelCaseToTitleCase(name, separator: ' ');

  bool get isLedger => name.startsWith('ledger');

  bool get isBitBox => name.startsWith('bitbox');

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
      case SignerDeviceEntity.specter:
        return QrType.urqr;
      default:
        return QrType.none;
    }
  }
}
