import 'package:bb_mobile/features/import_mnemonic/locator.dart';
import 'package:bb_mobile/features/import_mnemonic/router.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bb_mobile/features/settings/ui/settings_item.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

class _Settings extends Fake implements SettingsFacade {
  final entries = <SettingsEntryContribution>[];

  @override
  void registerEntry(SettingsEntryContribution contribution) =>
      entries.add(contribution);
}

void main() {
  testWidgets(
    'the Import seed setting opens the existing mnemonic route directly',
    (tester) async {
      final locator = GetIt.asNewInstance();
      addTearDown(locator.reset);
      final settings = _Settings();
      locator.registerSingleton<SettingsFacade>(settings);
      ImportMnemonicLocator.setup(locator);
      expect(settings.entries, hasLength(1));
      final entry = settings.entries.single;
      expect(entry.id, 'import-seed');
      expect(entry.section, SettingsEntrySection.wallet);
      final item = buildSettingsItems(
        localization: AppLocalizationsEn(),
        contributions: settings.entries,
      ).byId(SettingsItemId.extension);
      expect(item.title, 'Import seed');
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(body: item.buildTile(context)),
          ),
          GoRoute(
            path: ImportMnemonicRoute.importMnemonicHome.path,
            name: ImportMnemonicRoute.importMnemonicHome.name,
            builder: (_, _) =>
                const Scaffold(body: Text('Existing seed import')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
      await tester.tap(find.text('Import seed'));
      await tester.pumpAndSettle();
      expect(find.text('Existing seed import'), findsOneWidget);
    },
  );
}
