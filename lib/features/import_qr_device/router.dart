import 'package:signers/signers.dart';
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
        final config = DeviceConfig.configs[SignerDevice.jade]!;
        return ImportQrDevicePage(
          device: config.device,
          deviceName: config.getName(context),
          instructionsTitle: config.getInstructionsTitle(context),
          instructions: config.getInstructions(context),
        );
      },
    ),
    GoRoute(
      name: ImportQrDeviceRoute.importKrux.name,
      path: ImportQrDeviceRoute.importKrux.path,
      builder: (context, state) {
        final config = DeviceConfig.configs[SignerDevice.krux]!;
        return ImportQrDevicePage(
          device: config.device,
          deviceName: config.getName(context),
          instructionsTitle: config.getInstructionsTitle(context),
          instructions: config.getInstructions(context),
        );
      },
    ),
    GoRoute(
      name: ImportQrDeviceRoute.importKeystone.name,
      path: ImportQrDeviceRoute.importKeystone.path,
      builder: (context, state) {
        final config = DeviceConfig.configs[SignerDevice.keystone]!;
        return ImportQrDevicePage(
          device: config.device,
          deviceName: config.getName(context),
          instructionsTitle: config.getInstructionsTitle(context),
          instructions: config.getInstructions(context),
        );
      },
    ),
    GoRoute(
      name: ImportQrDeviceRoute.importPassport.name,
      path: ImportQrDeviceRoute.importPassport.path,
      builder: (context, state) {
        final config = DeviceConfig.configs[SignerDevice.passport]!;
        return ImportQrDevicePage(
          device: config.device,
          deviceName: config.getName(context),
          instructionsTitle: config.getInstructionsTitle(context),
          instructions: config.getInstructions(context),
        );
      },
    ),
    GoRoute(
      name: ImportQrDeviceRoute.importSeedSigner.name,
      path: ImportQrDeviceRoute.importSeedSigner.path,
      builder: (context, state) {
        final config = DeviceConfig.configs[SignerDevice.seedsigner]!;
        return ImportQrDevicePage(
          device: config.device,
          deviceName: config.getName(context),
          instructionsTitle: config.getInstructionsTitle(context),
          instructions: config.getInstructions(context),
        );
      },
    ),
    GoRoute(
      name: ImportQrDeviceRoute.importSpecter.name,
      path: ImportQrDeviceRoute.importSpecter.path,
      builder: (context, state) {
        final config = DeviceConfig.configs[SignerDevice.specter]!;
        return ImportQrDevicePage(
          device: config.device,
          deviceName: config.getName(context),
          instructionsTitle: config.getInstructionsTitle(context),
          instructions: config.getInstructions(context),
        );
      },
    ),
  ];
}
