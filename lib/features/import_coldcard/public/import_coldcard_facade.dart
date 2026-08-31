import 'package:bb_mobile/core/entities/signer_device_entity.dart';

final class ScanColdcardAccountKeyRequest {
  final String derivationPath;

  const ScanColdcardAccountKeyRequest({required this.derivationPath});
}

final class ImportColdcardFacade {
  const ImportColdcardFacade();

  String accountKeyRouteName(SignerDeviceEntity device) => switch (device) {
    SignerDeviceEntity.coldcardQ => 'importColdcardQ',
    SignerDeviceEntity.coldcardMk4 => 'importColdcardMk4',
    _ => throw ArgumentError.value(
      device,
      'device',
      'Device does not use the Coldcard import flow',
    ),
  };
}
