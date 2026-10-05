import 'package:bb_mobile/core/utils/string_formatting.dart';

enum QrType { none, bbqr, urqr }

enum SignerDeviceEntity {
  bitbox02,
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
  seedsigner,
  specter;

  String get displayName => switch (this) {
    SignerDeviceEntity.bitbox02 => 'BitBox02',
    SignerDeviceEntity.ledgerNanoSPlus => 'Ledger Nano S Plus',
    SignerDeviceEntity.seedsigner => 'SeedSigner',
    _ => StringFormatting.camelCaseToTitleCase(name, separator: ' '),
  };

  bool get isLedger => name.startsWith('ledger');

  bool get isBitBox => name.startsWith('bitbox');

  bool get supportsBluetooth =>
      isLedger && this != SignerDeviceEntity.ledgerNanoSPlus;

  bool get supportsComplexTaprootRegistration => switch (this) {
    SignerDeviceEntity.bitbox02 ||
    SignerDeviceEntity.krux ||
    SignerDeviceEntity.ledgerNanoSPlus ||
    SignerDeviceEntity.ledgerNanoX ||
    SignerDeviceEntity.ledgerFlex ||
    SignerDeviceEntity.ledgerStax ||
    SignerDeviceEntity.specter => true,
    SignerDeviceEntity.coldcardQ ||
    SignerDeviceEntity.coldcardMk4 ||
    SignerDeviceEntity.jade ||
    SignerDeviceEntity.keystone ||
    SignerDeviceEntity.passport ||
    SignerDeviceEntity.seedsigner => false,
  };

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
