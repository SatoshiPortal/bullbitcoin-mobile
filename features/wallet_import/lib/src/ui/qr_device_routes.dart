import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wallet_import/src/import_navigation.dart';
import 'package:wallet_import/src/presentation/import_l10n.dart';
import 'package:wallet_import/src/ui/device_config.dart';
import 'package:wallet_import/src/ui/import_qr_device_page.dart';

List<RouteBase> qrDeviceRoutes(ImageProvider<Object> illustration) => [
  for (final device in QrImportDevice.values)
    GoRoute(
      name: device.routeName,
      path: device.path,
      builder: (context, state) {
        final config = DeviceConfig.configs[device.signer];
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
          illustration: illustration,
        );
      },
    ),
];
