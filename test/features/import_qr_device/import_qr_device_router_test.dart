import 'package:bb_mobile/features/import_qr_device/device_config.dart';
import 'package:bb_mobile/features/import_qr_device/import_qr_device_page.dart';
import 'package:bb_mobile/features/import_qr_device/router.dart';
import 'package:bb_mobile/localizations.dart';
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
      initialLocation: ImportQrDeviceRoute.importJade.path,
      routes: ImportQrDeviceRouter.routes,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();

    final loc = await AppLocalizations.delegate.load(locale);
    expect(tester.takeException(), isNull);
    expect(find.text(loc.oopsSomethingWentWrong), findsOneWidget);
    expect(find.byType(ImportQrDevicePage), findsNothing);
  });
}
