import 'package:bb_mobile/features/import_wallet/router.dart';
import 'package:bb_mobile/features/settings/public/settings_entry_registry.dart';
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

    await tester.tap(find.text(localization.walletSettingsImportWalletTitle));
    await tester.pumpAndSettle();

    expect(find.text('Import wallet destination'), findsOneWidget);
  });

  testWidgets('a contributed wallet setting opens its feature route', (
    tester,
  ) async {
    final localization = AppLocalizationsEn();
    final item = buildSettingsItems(
      localization: localization,
      contributions: [
        SettingsEntryContribution(
          id: 'vault',
          section: SettingsEntrySection.wallet,
          title: (_) => 'Create vault',
          icon: Icons.security,
          open: (context) => context.pushNamed('create-vault'),
        ),
      ],
    ).byId(SettingsItemId.extension);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(body: item.buildTile(context)),
        ),
        GoRoute(
          name: 'create-vault',
          path: '/create-vault',
          builder: (context, state) => const Text('Vault destination'),
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

    await tester.tap(find.text('Create vault'));
    await tester.pumpAndSettle();

    expect(find.text('Vault destination'), findsOneWidget);
  });
}
