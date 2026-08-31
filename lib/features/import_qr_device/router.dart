import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/features/import_qr_device/device_config.dart';
import 'package:bb_mobile/features/import_qr_device/import_qr_device_page.dart';
import 'package:bb_mobile/features/import_qr_device/public/import_qr_device_facade.dart';
import 'package:flutter/widgets.dart';
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
        return _page(context, state, config);
      },
    ),
    GoRoute(
      name: ImportQrDeviceRoute.importKrux.name,
      path: ImportQrDeviceRoute.importKrux.path,
      builder: (context, state) {
        final config = DeviceConfig.configs[SignerDeviceEntity.krux]!;
        return _page(context, state, config);
      },
    ),
    GoRoute(
      name: ImportQrDeviceRoute.importKeystone.name,
      path: ImportQrDeviceRoute.importKeystone.path,
      builder: (context, state) {
        final config = DeviceConfig.configs[SignerDeviceEntity.keystone]!;
        return _page(context, state, config);
      },
    ),
    GoRoute(
      name: ImportQrDeviceRoute.importPassport.name,
      path: ImportQrDeviceRoute.importPassport.path,
      builder: (context, state) {
        final config = DeviceConfig.configs[SignerDeviceEntity.passport]!;
        return _page(context, state, config);
      },
    ),
    GoRoute(
      name: ImportQrDeviceRoute.importSeedSigner.name,
      path: ImportQrDeviceRoute.importSeedSigner.path,
      builder: (context, state) {
        final config = DeviceConfig.configs[SignerDeviceEntity.seedsigner]!;
        return _page(context, state, config);
      },
    ),
    GoRoute(
      name: ImportQrDeviceRoute.importSpecter.name,
      path: ImportQrDeviceRoute.importSpecter.path,
      builder: (context, state) {
        final config = DeviceConfig.configs[SignerDeviceEntity.specter]!;
        return _page(context, state, config);
      },
    ),
  ];

  static ImportQrDevicePage _page(
    BuildContext context,
    GoRouterState state,
    DeviceConfig config,
  ) {
    final request = state.extra as ScanQrDeviceAccountKeyRequest?;
    return ImportQrDevicePage(
      device: config.device,
      deviceName: config.getName(context),
      instructionsTitle: config.getInstructionsTitle(context),
      instructions: config.getInstructions(context),
      accountKeyDerivationPath: request?.derivationPath,
    );
  }
}
