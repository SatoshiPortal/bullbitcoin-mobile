import 'package:bb_mobile/features/settings/public/settings_entry_registry.dart';
import 'package:bb_mobile/features/settings/ui/settings_item.dart';
import 'package:bb_mobile/features/settings/ui/settings_search.dart';
import 'package:bb_mobile/generated/l10n/localization_as.dart';
import 'package:bb_mobile/generated/l10n/localization_de.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:bb_mobile/generated/l10n/localization_fr.dart';
import 'package:flutter/material.dart';
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

    test('Nostr keys sit under Tools, and their breadcrumb says so', () {
      final english = AppLocalizationsEn();
      final item = _englishItems().singleWhere(
        (item) => item.id == SettingsItemId.nostrKeys,
      );

      expect(item.section, SettingsItemSection.tools);
      expect(item.path, [
        english.settingsScreenTitle,
        english.settingsToolsTitle,
        english.settingsNostrKeysTitle,
      ]);
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

    test('places wallet import under Wallet and Bitcoin', () {
      final items = _englishItems();

      expect(items.byId(SettingsItemId.backup).title, 'Wallet Recovery');
      expect(
        items.byId(SettingsItemId.importWallet).section,
        SettingsItemSection.wallet,
      );
      expect(
        items.byId(SettingsItemId.importWallet).location(TextDirection.ltr),
        'Settings → Wallet and Bitcoin → Import wallet',
      );
      expect(backupSettingsDataItemOrder, [
        SettingsItemId.labels,
        SettingsItemId.transactionHistory,
      ]);
    });

    test('Wallet and Bitcoin holds the requested entries in order', () {
      final items = _englishItems(
        isSuperuser: true,
      ).ordered(SettingsItemSection.wallet, walletSettingsItemOrder);

      expect(
        items
            .where((item) => item.id != SettingsItemId.signingKeyExport)
            .map((item) => item.id),
        [
          SettingsItemId.backup,
          SettingsItemId.dataBackup,
          SettingsItemId.importWallet,
          SettingsItemId.passphraseWallets,
          SettingsItemId.electrum,
          SettingsItemId.mempool,
          SettingsItemId.autoswap,
          SettingsItemId.payjoin,
          SettingsItemId.seedViewer,
          SettingsItemId.swapRestore,
        ],
      );
    });

    test('a contributed wallet entry takes the BULLVAULT slot', () {
      final items = buildSettingsItems(
        localization: AppLocalizationsEn(),
        isSuperuser: true,
        contributions: [
          SettingsEntryContribution(
            id: 'bullvault',
            section: SettingsEntrySection.wallet,
            title: (localization) => localization.settingsBullVaultEntryTitle,
            icon: Icons.security,
            open: (_) {},
          ),
        ],
      );

      final ordered = items
          .ordered(SettingsItemSection.wallet, walletSettingsItemOrder)
          .where((item) => item.id != SettingsItemId.signingKeyExport)
          .toList();

      expect(ordered[8].title, 'BullVault (miniscript)');
      expect(ordered[9].id, SettingsItemId.seedViewer);
      expect(ordered[10].id, SettingsItemId.swapRestore);
    });

    test('Seed Viewer keeps its superuser guard after the move', () {
      expect(
        _englishItems().map((item) => item.id),
        isNot(contains(SettingsItemId.seedViewer)),
      );
      expect(
        _englishItems(
          isSuperuser: true,
        ).byId(SettingsItemId.seedViewer).isSuperuser,
        isTrue,
      );
    });

    test('BIP85 stays upstream-guarded, under Tools', () {
      expect(
        _englishItems(isSuperuser: true).map((item) => item.id),
        isNot(contains(SettingsItemId.bip85)),
      );
      final bip85 = _englishItems(
        isSuperuser: true,
        isDevModeEnabled: true,
      ).byId(SettingsItemId.bip85);
      expect(bip85.section, SettingsItemSection.tools);
      expect(bip85.isSuperuser, isTrue);
      expect(
        bip85.location(TextDirection.ltr),
        'Settings → Tools → BIP85 Deterministic Entropies',
      );
    });

    test('the data exports are found under Data Backup', () {
      for (final id in backupSettingsDataItemOrder) {
        final item = _englishItems().byId(id);
        expect(item.path.sublist(0, 3), [
          'Settings',
          'Wallet and Bitcoin',
          'Data Backup',
        ]);
      }
    });

    test('wallet recovery entries are found under Wallet Recovery', () {
      for (final id in [
        SettingsItemId.startBackup,
        SettingsItemId.recoverbull,
      ]) {
        final item = _englishItems().byId(id);
        expect(item.section, SettingsItemSection.backup);
        expect(item.path.sublist(0, 3), [
          'Settings',
          'Wallet and Bitcoin',
          'Wallet Recovery',
        ]);
      }
    });

    test('the root holds exactly the five requested groups, in order', () {
      final items = _englishItems(isSuperuser: true, isDevModeEnabled: true);
      final rootItems = items.inSection(SettingsItemSection.root);

      expect(rootItems.map((item) => item.id), [
        SettingsItemId.walletSettings,
        SettingsItemId.exchange,
        SettingsItemId.appSettings,
        SettingsItemId.tools,
        SettingsItemId.helpAndInfo,
      ]);
      expect(rootItems.map((item) => item.title), [
        'Wallet and Bitcoin',
        'Exchange',
        'App and device',
        'Tools',
        'Help and info',
      ]);
      expect(items.byId(SettingsItemId.autoswap).title, 'Auto Transfer');
      expect(items.byId(SettingsItemId.electrum).title, 'Electrum Server');
      expect(items.byId(SettingsItemId.mempool).title, 'Mempool Server');
    });

    test('Tools lists the reviewed entries', () {
      expect(
        _englishItems(
          isSuperuser: true,
          isDevModeEnabled: true,
        ).inSection(SettingsItemSection.tools).map((item) => item.id),
        [
          SettingsItemId.broadcastTransaction,
          SettingsItemId.nostrKeys,
          SettingsItemId.btcMap,
          SettingsItemId.bip85,
        ],
      );
    });

    test('Help and info lists the reviewed entries', () {
      expect(
        _englishItems()
            .inSection(SettingsItemSection.help)
            .map((item) => item.id),
        [
          SettingsItemId.supportChat,
          SettingsItemId.github,
          SettingsItemId.termsOfService,
          SettingsItemId.servicesStatus,
          SettingsItemId.logs,
        ],
      );
    });

    test('the renamed groups keep their previous names as aliases', () {
      final items = _englishItems();
      final aliases = {
        'Wallet': SettingsItemId.walletSettings,
        'Wallet Settings': SettingsItemId.walletSettings,
        'App': SettingsItemId.appSettings,
        'App Settings': SettingsItemId.appSettings,
      };

      for (final MapEntry(key: query, value: id) in aliases.entries) {
        expect(
          searchSettings(items, query).map((item) => item.id),
          contains(id),
          reason: 'Expected "$query" to still find ${id.name}',
        );
      }
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
        'passphrase': SettingsItemId.passphraseWallets,
        'private wallet': SettingsItemId.passphraseWallets,
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
        'Settings → Wallet and Bitcoin → Data Backup → Transaction History',
      );
      expect(
        result.location(TextDirection.rtl),
        'Settings ← Wallet and Bitcoin ← Data Backup ← Transaction History',
      );
    });

    test('omits inaccessible superuser settings', () {
      final items = _englishItems();

      // "App and device" contains "dev", so a loose token match can still
      // surface an unrelated row; what must never appear is the guarded item.
      for (final MapEntry(key: query, value: id) in {
        'dev mode': SettingsItemId.devMode,
        'seed viewer': SettingsItemId.seedViewer,
        'testnet user credentials': SettingsItemId.testnetCredentials,
        'bip85': SettingsItemId.bip85,
      }.entries) {
        expect(
          searchSettings(items, query).map((item) => item.id),
          isNot(contains(id)),
          reason: 'Expected "$query" not to reveal ${id.name}',
        );
      }
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
      final builtInIds = SettingsItemId.values
          .where((id) => id != SettingsItemId.extension)
          .toSet();

      expect(items.map((item) => item.id).toSet(), builtInIds);
      expect(items, hasLength(builtInIds.length));
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
