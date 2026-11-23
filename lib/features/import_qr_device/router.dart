import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/import_qr_device/device_config.dart';
import 'package:bb_mobile/features/import_qr_device/import_qr_device_page.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signers/signers.dart';

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
    for (final (route, device) in [
      (ImportQrDeviceRoute.importJade, SignerDevice.jade),
      (ImportQrDeviceRoute.importKrux, SignerDevice.krux),
      (ImportQrDeviceRoute.importKeystone, SignerDevice.keystone),
      (ImportQrDeviceRoute.importPassport, SignerDevice.passport),
      (ImportQrDeviceRoute.importSeedSigner, SignerDevice.seedsigner),
      (ImportQrDeviceRoute.importSpecter, SignerDevice.specter),
    ])
      GoRoute(
        name: route.name,
        path: route.path,
        builder: (context, state) {
          final config = DeviceConfig.configs[device];
          if (config == null) {
            return Scaffold(
              appBar: AppBar(),
              body: Center(child: Text(context.loc.oopsSomethingWentWrong)),
            );
          }
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
