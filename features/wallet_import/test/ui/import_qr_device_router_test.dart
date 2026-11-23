import 'package:wallet_import/src/ui/device_config.dart';
import 'package:wallet_import/src/ui/import_qr_device_page.dart';
import 'package:wallet_import/src/ui/qr_device_routes.dart';
import 'package:wallet_import/wallet_import.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signers/signers.dart';

void main() {
  testWidgets('missing QR device configuration shows a localized error', (
    tester,
  ) async {
    const device = SignerDevice.jade;
    final config = DeviceConfig.configs.remove(device);
    if (config != null) {
      addTearDown(() => DeviceConfig.configs[device] = config);
    }
    expect(config, isNotNull);

    const locale = Locale('fr');
    final router = GoRouter(
      initialLocation: QrImportDevice.jade.path,
      routes: qrDeviceRoutes(const AssetImage('unused.png')),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        locale: locale,
        localizationsDelegates: const [
          ImportLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: ImportLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();

    final loc = await ImportLocalizations.delegate.load(locale);
    expect(tester.takeException(), isNull);
    expect(find.text(loc.oopsSomethingWentWrong), findsOneWidget);
    expect(find.byType(ImportQrDevicePage), findsNothing);
  });
}
