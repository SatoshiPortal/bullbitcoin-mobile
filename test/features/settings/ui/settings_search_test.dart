import 'package:primitives/primitives.dart' show NetworkEnv;
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

    test('finds the localized fee source on supported Bitcoin networks', () {
      for (final environment in [NetworkEnv.mainnet, NetworkEnv.testnet]) {
        final items = buildSettingsItems(
          environment: environment,
          localization: AppLocalizationsFr(),
        );
        final results = searchSettings(items, 'source des frais bitcoin');
        expect(results.first.id, SettingsItemId.feeSource);
        expect(results.first.section, SettingsItemSection.wallet);
      }

      final regtest = buildSettingsItems(
        environment: NetworkEnv.regtest,
        localization: AppLocalizationsFr(),
      );
      expect(
        regtest.any((item) => item.id == SettingsItemId.feeSource),
        isFalse,
      );
    });

    test('matches a dedicated English keyword', () {
      final results = searchSettings(_englishItems(), 'block explorer');

      expect(results, hasLength(1));
      expect(results.single.id, SettingsItemId.mempool);
    });

    test('matches a dedicated Assamese keyword', () {
      final localization = AppLocalizationsAs();
      final items = buildSettingsItems(
        environment: NetworkEnv.mainnet,
        localization: localization,
      );

      final results = searchSettings(items, 'ব্লক এক্সপ্লোৰাৰ');

      expect(results, hasLength(1));
      expect(results.single.id, SettingsItemId.mempool);
    });

    test('matches dedicated metadata for another localized setting', () {
      final localization = AppLocalizationsAs();
      final items = buildSettingsItems(
        environment: NetworkEnv.mainnet,
        localization: localization,
      );

      final results = searchSettings(items, 'আন্ধাৰ');

      expect(results.first.id, SettingsItemId.theme);
    });

    test('keeps English terms as a fallback in another locale', () {
      final localization = AppLocalizationsAs();
      final items = buildSettingsItems(
        environment: NetworkEnv.mainnet,
        localization: localization,
      );

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
      final items = _englishItems(
        isSuperuser: true,
        isDevModeEnabled: true,
        accountReady: true,
        backgroundTasksAvailable: true,
      );
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
        'Settings → Wallet → Import Wallet',
      );
      expect(backupSettingsDataItemOrder, [
        SettingsItemId.labels,
        SettingsItemId.transactionHistory,
      ]);
      expect(walletSettingsItemOrder, [
        SettingsItemId.payjoin,
        SettingsItemId.ark,
        SettingsItemId.autoswap,
        SettingsItemId.swaps,
        SettingsItemId.swapRestore,
        SettingsItemId.importWallet,
        SettingsItemId.electrum,
        SettingsItemId.mempool,
        SettingsItemId.feeSource,
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
        SettingsItemId.termsOfService,
        SettingsItemId.servicesStatus,
        SettingsItemId.logs,
        SettingsItemId.sourceCode,
      ]);
      expect(rootItems.map((item) => item.title), [
        'App',
        'Backup',
        'Wallet',
        'Exchange',
        'Terms of Service',
        'Service Status',
        'Logs',
        'Source code',
      ]);
      expect(items.byId(SettingsItemId.autoswap).title, 'Auto Swap');
      expect(items.byId(SettingsItemId.electrum).title, 'Electrum Server');
      expect(items.byId(SettingsItemId.mempool).title, 'Mempool Server');
    });

    test('lists quick actions and the dark mode switch in App Settings', () {
      final items = _englishItems();

      expect(
        items.byId(SettingsItemId.quickActions).section,
        SettingsItemSection.app,
      );
      final theme = items.byId(SettingsItemId.theme);
      expect(theme.title, 'Dark Mode');
      expect(theme.isInlineControl, isTrue);
    });

    test('account settings is listed only when exchange is ready', () {
      final hidden = buildSettingsItems(
        environment: NetworkEnv.mainnet,
        localization: AppLocalizationsEn(),
      );
      final ready = buildSettingsItems(
        environment: NetworkEnv.mainnet,
        localization: AppLocalizationsEn(),
        accountReady: true,
      );
      expect(
        hidden.map((item) => item.id),
        isNot(contains(SettingsItemId.exchangeAccountSettings)),
      );
      expect(
        ready.byId(SettingsItemId.exchangeAccountSettings).title,
        'Account Settings',
      );
    });

    test('groups developer controls at the bottom of App Settings', () {
      final ids = _englishItems(
        isSuperuser: true,
        isDevModeEnabled: true,
      ).inSection(SettingsItemSection.app).map((item) => item.id).toList();

      // Tests run in debug mode, so the debug-only Ark notification item is listed.
      expect(ids.sublist(ids.length - 5), [
        SettingsItemId.errorReporting,
        SettingsItemId.devMode,
        SettingsItemId.testnetMode,
        SettingsItemId.arkDebugNotification,
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
      final items = _englishItems(
        isSuperuser: true,
        isDevModeEnabled: true,
        accountReady: true,
        backgroundTasksAvailable: true,
      );
      final expectedIds = {
        'trading': SettingsItemId.exchange,
        'seed backup': SettingsItemId.backup,
        'create backup': SettingsItemId.startBackup,
        'cloud backup': SettingsItemId.recoverbull,
        'transaction labels': SettingsItemId.labels,
        'CSV': SettingsItemId.transactionHistory,
        'network settings': SettingsItemId.walletSettings,
        'general settings': SettingsItemId.appSettings,
        'user agreement': SettingsItemId.termsOfService,
        'service health': SettingsItemId.servicesStatus,
        'watch-only wallet': SettingsItemId.importWallet,
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
        'orbot': SettingsItemId.tor,
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
      final credentials = _englishItems(isDevModeEnabled: true)
          .byId(SettingsItemId.testnetCredentials);

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

    test('matches the restored German Tor keywords', () {
      final results = searchSettings(_germanItems(), 'Integriertes Tor');

      expect(results.map((item) => item.id), contains(SettingsItemId.tor));
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

    test('permissions are found by their keywords where tasks run', () {
      expect(
        searchSettings(
          _englishItems(backgroundTasksAvailable: true),
          'notifications',
        ).map((item) => item.id),
        contains(SettingsItemId.permissions),
      );
      expect(
        _englishItems().map((item) => item.id),
        isNot(contains(SettingsItemId.permissions)),
      );
    });

    test('still reports no match for a query nothing contains', () {
      expect(searchSettings(_frenchItems(), 'zzz'), isEmpty);
    });

    // Some items exist only on some networks (Ark is regtest only), so the registry is the union over every network.
    test('every item id has one authoritative registry entry', () {
      final ids = <SettingsItemId>{};
      for (final environment in NetworkEnv.values) {
        final items = _englishItems(
          isSuperuser: true,
          isDevModeEnabled: true,
          accountReady: true,
          backgroundTasksAvailable: true,
          environment: environment,
        );
        final unique = items.map((item) => item.id).toSet();
        expect(unique, hasLength(items.length), reason: environment.name);
        ids.addAll(unique);
      }

      expect(ids, SettingsItemId.values.toSet());
    });
  });
}

List<SettingsItem> _englishItems({
  bool isSuperuser = false,
  bool isDevModeEnabled = false,
  bool accountReady = false,
  bool backgroundTasksAvailable = false,
  NetworkEnv environment = NetworkEnv.mainnet,
}) {
  final localization = AppLocalizationsEn();
  return buildSettingsItems(
    environment: environment,
    localization: localization,
    isSuperuser: isSuperuser,
    isDevModeEnabled: isDevModeEnabled,
    accountReady: accountReady,
    backgroundTasksAvailable: backgroundTasksAvailable,
  );
}

List<SettingsItem> _frenchItems() {
  final localization = AppLocalizationsFr();
  return buildSettingsItems(
    environment: NetworkEnv.mainnet,
    localization: localization,
  );
}

List<SettingsItem> _germanItems() {
  final localization = AppLocalizationsDe();
  return buildSettingsItems(
    environment: NetworkEnv.mainnet,
    localization: localization,
  );
}
