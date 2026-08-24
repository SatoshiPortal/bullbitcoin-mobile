import 'package:bb_mobile/core/entities/signer_device_entity.dart';

enum WalletRegistrationQrEncoding { none, urBytes, bbqrText }

enum WalletRegistrationUnavailableReason {
  unsupportedPolicy,
  unsupportedKeyOrigins,
}

sealed class WalletRegistrationOption {
  final SignerDeviceEntity device;

  const WalletRegistrationOption({required this.device});
}

final class AvailableWalletRegistration extends WalletRegistrationOption {
  final String qrData;
  final WalletRegistrationQrEncoding qrEncoding;
  final String fileData;
  final String fileName;

  const AvailableWalletRegistration({
    required super.device,
    required this.qrData,
    required this.qrEncoding,
    required this.fileData,
    required this.fileName,
  });
}

final class ConnectedWalletRegistration extends WalletRegistrationOption {
  const ConnectedWalletRegistration({required super.device});
}

final class UnavailableWalletRegistration extends WalletRegistrationOption {
  final WalletRegistrationUnavailableReason reason;

  const UnavailableWalletRegistration({
    required super.device,
    required this.reason,
  });
}

extension WalletRegistrationDeviceSupport on SignerDeviceEntity {
  bool get supportsWalletRegistration =>
      supportsWalletRegistrationExport || isBitBox || isLedger;

  bool get supportsWalletRegistrationExport => switch (this) {
    SignerDeviceEntity.coldcardQ ||
    SignerDeviceEntity.coldcardMk4 ||
    SignerDeviceEntity.jade ||
    SignerDeviceEntity.keystone ||
    SignerDeviceEntity.krux ||
    SignerDeviceEntity.passport ||
    SignerDeviceEntity.seedsigner ||
    SignerDeviceEntity.specter => true,
    SignerDeviceEntity.bitbox02 ||
    SignerDeviceEntity.ledgerNanoSPlus ||
    SignerDeviceEntity.ledgerNanoX ||
    SignerDeviceEntity.ledgerFlex ||
    SignerDeviceEntity.ledgerStax => false,
  };
}
