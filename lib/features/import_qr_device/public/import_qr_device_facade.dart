import 'package:bb_mobile/core/entities/signer_device_entity.dart';

final class ScanQrDeviceAccountKeyRequest {
  final String derivationPath;

  const ScanQrDeviceAccountKeyRequest({required this.derivationPath});
}

final class ImportQrDeviceFacade {
  const ImportQrDeviceFacade();

  String accountKeyRouteName(SignerDeviceEntity device) => switch (device) {
    SignerDeviceEntity.jade => 'importJade',
    SignerDeviceEntity.krux => 'importKrux',
    SignerDeviceEntity.keystone => 'importKeystone',
    SignerDeviceEntity.passport => 'importPassport',
    SignerDeviceEntity.seedsigner => 'importSeedSigner',
    SignerDeviceEntity.specter => 'importSpecter',
    _ => throw ArgumentError.value(
      device,
      'device',
      'Device does not use the QR import flow',
    ),
  };
}
