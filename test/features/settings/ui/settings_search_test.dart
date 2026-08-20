import 'package:bb_mobile/features/settings/ui/settings_item.dart';
import 'package:bb_mobile/features/settings/ui/settings_search.dart';
import 'package:bb_mobile/generated/l10n/localization_as.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
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
      final items = buildSettingsItems(
        localization: localization,
        exchangeTitle: localization.settingsExchangeSettingsTitle,
      );

      final results = searchSettings(items, 'ব্লক এক্সপ্লোৰাৰ');

      expect(results, hasLength(1));
      expect(results.single.id, SettingsItemId.mempool);
    });

    test('matches dedicated metadata for another localized setting', () {
      final localization = AppLocalizationsAs();
      final items = buildSettingsItems(
        localization: localization,
        exchangeTitle: localization.settingsExchangeSettingsTitle,
      );

      final results = searchSettings(items, 'আন্ধাৰ');

      expect(results.first.id, SettingsItemId.theme);
    });

    test('keeps English terms as a fallback in another locale', () {
      final localization = AppLocalizationsAs();
      final items = buildSettingsItems(
        localization: localization,
        exchangeTitle: localization.settingsExchangeSettingsTitle,
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

      expect(results.first.id, SettingsItemId.bitcoinSettings);
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

    test('supports dedicated semantic aliases across the registry', () {
      final items = _englishItems(isSuperuser: true, isDevModeEnabled: true);
      final expectedIds = {
        'trading': SettingsItemId.exchange,
        'seed backup': SettingsItemId.walletBackup,
        'create backup': SettingsItemId.startBackup,
        'cloud backup': SettingsItemId.recoverbull,
        'transaction labels': SettingsItemId.labels,
        'CSV': SettingsItemId.transactionHistory,
        'network settings': SettingsItemId.bitcoinSettings,
        'general settings': SettingsItemId.appSettings,
        'merchant map': SettingsItemId.btcMap,
        'user agreement': SettingsItemId.termsOfService,
        'service health': SettingsItemId.servicesStatus,
        'manage wallets': SettingsItemId.wallets,
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
        'onion routing': SettingsItemId.tor,
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
        'Settings → Wallet Backup → Transaction History',
      );
      expect(
        result.location(TextDirection.rtl),
        'Settings ← Wallet Backup ← Transaction History',
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
    exchangeTitle: localization.settingsExchangeSettingsTitle,
    isSuperuser: isSuperuser,
    isDevModeEnabled: isDevModeEnabled,
  );
}
