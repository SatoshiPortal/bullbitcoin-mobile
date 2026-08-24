import 'package:bb_mobile/features/import_wallet/router.dart';
import 'package:bb_mobile/features/settings/ui/settings_item.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('a registry item opens its dedicated route directly', (
    tester,
  ) async {
    final localization = AppLocalizationsEn();
    final item = buildSettingsItems(
      localization: localization,
      exchangeTitle: localization.settingsExchangeSettingsTitle,
    ).byId(SettingsItemId.importWallet);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(body: item.buildTile(context)),
        ),
        GoRoute(
          name: ImportWalletRoute.importWalletHome.name,
          path: ImportWalletRoute.importWalletHome.path,
          builder: (context, state) => const Text('Import wallet destination'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );

    await tester.tap(find.text(localization.bitcoinSettingsImportWalletTitle));
    await tester.pumpAndSettle();

    expect(find.text('Import wallet destination'), findsOneWidget);
  });
}
