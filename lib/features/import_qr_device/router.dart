import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/features/import_qr_device/device_config.dart';
import 'package:bb_mobile/features/import_qr_device/import_qr_device_page.dart';
import 'package:go_router/go_router.dart';

enum ImportQrDeviceRoute {
  importJade('/import-jade'),
  importKrux('/import-krux'),
  importKeystone('/import-keystone'),
  importPassport('/import-passport'),
  importSeedSigner('/import-seedsigner'),
  importSpecter('/import-specter');

  final String path;

  const ImportQrDeviceRoute(this.path);
}

class ImportQrDeviceRouter {
  static final routes = [
    GoRoute(
      name: ImportQrDeviceRoute.importJade.name,
      path: ImportQrDeviceRoute.importJade.path,
      builder: (context, state) {
        final config = DeviceConfig.configs[SignerDeviceEntity.jade]!;
        return ImportQrDevicePage(
          device: config.device,
          deviceName: config.name,
          instructionsTitle: config.instructionsTitle,
          instructions: config.instructions,
        );
      },
    ),
    GoRoute(
      name: ImportQrDeviceRoute.importKrux.name,
      path: ImportQrDeviceRoute.importKrux.path,
      builder: (context, state) {
        final config = DeviceConfig.configs[SignerDeviceEntity.krux]!;
        return ImportQrDevicePage(
          device: config.device,
          deviceName: config.name,
          instructionsTitle: config.instructionsTitle,
          instructions: config.instructions,
        );
      },
    ),
    GoRoute(
      name: ImportQrDeviceRoute.importKeystone.name,
      path: ImportQrDeviceRoute.importKeystone.path,
      builder: (context, state) {
        final config = DeviceConfig.configs[SignerDeviceEntity.keystone]!;
        return ImportQrDevicePage(
          device: config.device,
          deviceName: config.name,
          instructionsTitle: config.instructionsTitle,
          instructions: config.instructions,
        );
      },
    ),
    GoRoute(
      name: ImportQrDeviceRoute.importPassport.name,
      path: ImportQrDeviceRoute.importPassport.path,
      builder: (context, state) {
        final config = DeviceConfig.configs[SignerDeviceEntity.passport]!;
        return ImportQrDevicePage(
          device: config.device,
          deviceName: config.name,
          instructionsTitle: config.instructionsTitle,
          instructions: config.instructions,
        );
      },
    ),
    GoRoute(
      name: ImportQrDeviceRoute.importSeedSigner.name,
      path: ImportQrDeviceRoute.importSeedSigner.path,
      builder: (context, state) {
        final config = DeviceConfig.configs[SignerDeviceEntity.seedsigner]!;
        return ImportQrDevicePage(
          device: config.device,
          deviceName: config.name,
          instructionsTitle: config.instructionsTitle,
          instructions: config.instructions,
        );
      },
    ),
    GoRoute(
      name: ImportQrDeviceRoute.importSpecter.name,
      path: ImportQrDeviceRoute.importSpecter.path,
      builder: (context, state) {
        final config = DeviceConfig.configs[SignerDeviceEntity.specter]!;
        return ImportQrDevicePage(
          device: config.device,
          deviceName: config.name,
          instructionsTitle: config.instructionsTitle,
          instructions: config.instructions,
        );
      },
    ),
  ];
}
