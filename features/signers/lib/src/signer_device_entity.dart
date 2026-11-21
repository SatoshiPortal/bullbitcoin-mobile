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
    SignerDeviceEntity.coldcardQ => 'Coldcard Q',
    SignerDeviceEntity.coldcardMk4 => 'Coldcard Mk4',
    SignerDeviceEntity.jade => 'Jade',
    SignerDeviceEntity.keystone => 'Keystone',
    SignerDeviceEntity.krux => 'Krux',
    SignerDeviceEntity.ledgerNanoSPlus => 'Ledger Nano SPlus',
    SignerDeviceEntity.ledgerNanoX => 'Ledger Nano X',
    SignerDeviceEntity.ledgerFlex => 'Ledger Flex',
    SignerDeviceEntity.ledgerStax => 'Ledger Stax',
    SignerDeviceEntity.passport => 'Passport',
    SignerDeviceEntity.seedsigner => 'Seedsigner',
    SignerDeviceEntity.specter => 'Specter',
  };

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
