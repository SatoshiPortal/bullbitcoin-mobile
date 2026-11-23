enum QrType { none, bbqr, urqr }

enum SignerDevice {
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
    SignerDevice.bitbox02 => 'BitBox02',
    SignerDevice.coldcardQ => 'Coldcard Q',
    SignerDevice.coldcardMk4 => 'Coldcard Mk4',
    SignerDevice.jade => 'Jade',
    SignerDevice.keystone => 'Keystone',
    SignerDevice.krux => 'Krux',
    SignerDevice.ledgerNanoSPlus => 'Ledger Nano SPlus',
    SignerDevice.ledgerNanoX => 'Ledger Nano X',
    SignerDevice.ledgerFlex => 'Ledger Flex',
    SignerDevice.ledgerStax => 'Ledger Stax',
    SignerDevice.passport => 'Passport',
    SignerDevice.seedsigner => 'Seedsigner',
    SignerDevice.specter => 'Specter',
  };

  bool get isLedger => name.startsWith('ledger');

  bool get isBitBox => name.startsWith('bitbox');

  bool get supportsBluetooth =>
      isLedger && this != SignerDevice.ledgerNanoSPlus;

  QrType get supportedQrType {
    switch (this) {
      case SignerDevice.coldcardQ:
        return QrType.bbqr;
      case SignerDevice.jade:
      case SignerDevice.krux:
      case SignerDevice.keystone:
      case SignerDevice.passport:
      case SignerDevice.seedsigner:
      case SignerDevice.specter:
        return QrType.urqr;
      default:
        return QrType.none;
    }
  }
}
