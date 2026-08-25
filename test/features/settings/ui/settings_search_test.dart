import 'package:bb_mobile/features/settings/ui/settings_item.dart';
import 'package:bb_mobile/features/settings/ui/settings_search.dart';
import 'package:bb_mobile/generated/l10n/localization_as.dart';
import 'package:bb_mobile/generated/l10n/localization_de.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:bb_mobile/generated/l10n/localization_fr.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('settings search', () {
    test('matches an English localized title', () {
      final items = _englishItems();

      final results = searchSettings(items, 'mempool server');

      expect(results.first.id, SettingsItemId.mempool);
    });

    test('matches a dedicated English keyword', () {
      final results = searchSettings(_englishItems(), 'block explorer');

      expect(results, hasLength(1));
      expect(results.single.id, SettingsItemId.mempool);
    });

    test('matches a dedicated Assamese keyword', () {
      final localization = AppLocalizationsAs();
      final items = buildSettingsItems(localization: localization);

      final results = searchSettings(items, 'ব্লক এক্সপ্লোৰাৰ');

      expect(results, hasLength(1));
      expect(results.single.id, SettingsItemId.mempool);
    });

    test('matches dedicated metadata for another localized setting', () {
      final localization = AppLocalizationsAs();
      final items = buildSettingsItems(localization: localization);

      final results = searchSettings(items, 'আন্ধাৰ');

      expect(results.first.id, SettingsItemId.theme);
    });

    test('keeps English terms as a fallback in another locale', () {
      final localization = AppLocalizationsAs();
      final items = buildSettingsItems(localization: localization);

      final results = searchSettings(items, 'transaction fees');

      expect(results, hasLength(1));
      expect(results.single.id, SettingsItemId.mempool);
    });

    test('does not index user-facing descriptions', () {
      expect(searchSettings(_englishItems(), 'different networks'), isEmpty);
    });

    test('ranks a title match above section matches', () {
      final results = searchSettings(_englishItems(), 'bitcoin settings');

      expect(results.first.id, SettingsItemId.walletSettings);
    });

    test('includes nested backup and superuser settings', () {
      final items = _englishItems(isSuperuser: true, isDevModeEnabled: true);
      final expectedIds = {
        'dev mode': SettingsItemId.devMode,
        'testnet user credentials': SettingsItemId.testnetCredentials,
        'recoverbull': SettingsItemId.recoverbull,
        'transaction history': SettingsItemId.transactionHistory,
        'seed viewer': SettingsItemId.seedViewer,
      };

      for (final MapEntry(key: query, value: id) in expectedIds.entries) {
        expect(searchSettings(items, query).first.id, id);
      }
    });

    test('places wallet import under the Wallet section', () {
      final items = _englishItems();

      expect(items.byId(SettingsItemId.backup).title, 'Backup');
      expect(
        items.byId(SettingsItemId.importWallet).section,
        SettingsItemSection.wallet,
      );
      expect(
        items.byId(SettingsItemId.importWallet).location(TextDirection.ltr),
        'Settings → Wallet → Import wallet',
      );
      expect(backupSettingsDataItemOrder, [
        SettingsItemId.labels,
        SettingsItemId.transactionHistory,
      ]);
      expect(walletSettingsItemOrder, [
        SettingsItemId.payjoin,
        SettingsItemId.autoswap,
        SettingsItemId.importWallet,
        SettingsItemId.electrum,
        SettingsItemId.mempool,
        SettingsItemId.broadcastTransaction,
      ]);
    });

    test('orders and labels root settings for progressive disclosure', () {
      final items = _englishItems();
      final rootItems = items.inSection(SettingsItemSection.root);

      expect(rootItems.map((item) => item.id), [
        SettingsItemId.appSettings,
        SettingsItemId.backup,
        SettingsItemId.walletSettings,
        SettingsItemId.exchange,
        SettingsItemId.btcMap,
        SettingsItemId.termsOfService,
        SettingsItemId.servicesStatus,
        SettingsItemId.logs,
      ]);
      expect(rootItems.map((item) => item.title), [
        'App',
        'Backup',
        'Wallet',
        'Exchange',
        'Map',
        'Terms of Service',
        'Service Status',
        'Logs',
      ]);
      expect(items.byId(SettingsItemId.autoswap).title, 'Auto Transfer');
      expect(items.byId(SettingsItemId.electrum).title, 'Electrum Server');
      expect(items.byId(SettingsItemId.mempool).title, 'Mempool Server');
    });

    test('groups developer controls at the bottom of App Settings', () {
      final ids = _englishItems(
        isSuperuser: true,
        isDevModeEnabled: true,
      ).inSection(SettingsItemSection.app).map((item) => item.id).toList();

      expect(ids.sublist(ids.length - 4), [
        SettingsItemId.errorReporting,
        SettingsItemId.devMode,
        SettingsItemId.testnetMode,
        SettingsItemId.testnetCredentials,
      ]);
      expect(
        _englishItems(
          isSuperuser: true,
          isDevModeEnabled: true,
        ).byId(SettingsItemId.testnetMode).section,
        SettingsItemSection.app,
      );
    });

    test('supports dedicated semantic aliases across the registry', () {
      final items = _englishItems(isSuperuser: true, isDevModeEnabled: true);
      final expectedIds = {
        'trading': SettingsItemId.exchange,
        'seed backup': SettingsItemId.backup,
        'create backup': SettingsItemId.startBackup,
        'cloud backup': SettingsItemId.recoverbull,
        'transaction labels': SettingsItemId.labels,
        'CSV': SettingsItemId.transactionHistory,
        'network settings': SettingsItemId.walletSettings,
        'general settings': SettingsItemId.appSettings,
        'merchant map': SettingsItemId.btcMap,
        'user agreement': SettingsItemId.termsOfService,
        'service health': SettingsItemId.servicesStatus,
        'watch-only wallet': SettingsItemId.importWallet,
        'descriptor key': SettingsItemId.signingKeyExport,
        'transaction hex': SettingsItemId.broadcastTransaction,
        'collaborative transaction': SettingsItemId.payjoin,
        'automatic swap': SettingsItemId.autoswap,
        'personal node': SettingsItemId.electrum,
        'block explorer': SettingsItemId.mempool,
        'testing mode': SettingsItemId.testnetMode,
        'recovery phrase': SettingsItemId.seedViewer,
        'child seeds': SettingsItemId.bip85,
        'display language': SettingsItemId.language,
        'appearance': SettingsItemId.theme,
        'local currency': SettingsItemId.currency,
        'passcode': SettingsItemId.securityPin,
        'diagnostic logs': SettingsItemId.logs,
        'screen recording': SettingsItemId.screenPrivacy,
        'developer mode': SettingsItemId.devMode,
        'basic auth': SettingsItemId.testnetCredentials,
        'crash reports': SettingsItemId.errorReporting,
      };

      for (final MapEntry(key: query, value: id) in expectedIds.entries) {
        expect(
          searchSettings(items, query).first.id,
          id,
          reason: 'Expected "$query" to find ${id.name}',
        );
      }
    });

    test('describes where a nested result is found', () {
      final result = searchSettings(
        _englishItems(),
        'transaction history',
      ).single;

      expect(
        result.location(TextDirection.ltr),
        'Settings → Backup → Transaction History',
      );
      expect(
        result.location(TextDirection.rtl),
        'Settings ← Backup ← Transaction History',
      );
    });

    test('omits inaccessible superuser settings', () {
      final items = _englishItems();

      expect(searchSettings(items, 'dev mode'), isEmpty);
      expect(searchSettings(items, 'seed viewer'), isEmpty);
      expect(searchSettings(items, 'testnet user credentials'), isEmpty);
    });

    test('testnet credentials is not marked as a superuser item', () {
      final credentials = _englishItems(
        isDevModeEnabled: true,
      ).byId(SettingsItemId.testnetCredentials);

      expect(credentials.isSuperuser, isFalse);
    });

    test('matches a French title typed without its accents', () {
      final results = searchSettings(_frenchItems(), 'securite');

      expect(
        results.map((item) => item.id),
        contains(SettingsItemId.securityPin),
      );
    });

    test('matches a German title typed without its umlaut', () {
      final results = searchSettings(_germanItems(), 'wahrung');

      expect(results.map((item) => item.id), contains(SettingsItemId.currency));
    });

    test('matches a typographic apostrophe typed as a straight quote', () {
      final results = searchSettings(
        _frenchItems(),
        "confidentialite de l'ecran",
      );

      expect(
        results.map((item) => item.id),
        contains(SettingsItemId.screenPrivacy),
      );
    });

    test('matches a German keyword its German title does not contain', () {
      // The theme screen is labelled "Anzeige & Layout" in German, so the word
      // a user actually reaches for is only findable through the keywords.
      final results = searchSettings(_germanItems(), 'Dunkelmodus');

      expect(results.map((item) => item.id), contains(SettingsItemId.theme));
    });

    test('folds the German sharp s to a double s', () {
      final items = [
        SettingsItem(
          id: SettingsItemId.currency,
          section: SettingsItemSection.app,
          title: 'Große Beträge',
          path: const ['Einstellungen', 'Große Beträge'],
          icon: IconData(0),
          open: (_) {},
        ),
      ];

      expect(
        searchSettings(items, 'grosse betrage').map((item) => item.id),
        contains(SettingsItemId.currency),
      );
    });

    test('still reports no match for a query nothing contains', () {
      expect(searchSettings(_frenchItems(), 'zzz'), isEmpty);
    });

    test('every item id has one authoritative registry entry', () {
      final items = _englishItems(isSuperuser: true, isDevModeEnabled: true);

      expect(
        items.map((item) => item.id).toSet(),
        SettingsItemId.values.toSet(),
      );
      expect(items, hasLength(SettingsItemId.values.length));
    });
  });
}

List<SettingsItem> _englishItems({
  bool isSuperuser = false,
  bool isDevModeEnabled = false,
}) {
  final localization = AppLocalizationsEn();
  return buildSettingsItems(
    localization: localization,
    isSuperuser: isSuperuser,
    isDevModeEnabled: isDevModeEnabled,
  );
}

List<SettingsItem> _frenchItems() {
  final localization = AppLocalizationsFr();
  return buildSettingsItems(localization: localization);
}

List<SettingsItem> _germanItems() {
  final localization = AppLocalizationsDe();
  return buildSettingsItems(localization: localization);
}
