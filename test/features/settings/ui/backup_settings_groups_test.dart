import 'package:bb_mobile/features/settings/ui/settings_item.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final localization = AppLocalizationsEn();
  test('root Settings keeps exactly the five selected groups in order', () {
    final items = buildSettingsItems(localization: localization);
    expect(
      items.inSection(SettingsItemSection.root).map((item) => item.id.name),
      ['walletSettings', 'exchange', 'appSettings', 'tools', 'helpAndInfo'],
    );
    expect(
      items.map((item) => item.id.name),
      isNot(contains('passphraseWallets')),
    );
  });
  test(
    'wallet group reserves the selected order without a Passphrase slot',
    () {
      expect(walletSettingsItemOrder.map((id) => id.name), [
        'backup',
        'dataBackup',
        'importWallet',
        'electrum',
        'mempool',
        'autoswap',
        'payjoin',
        'extension',
        'seedViewer',
      ]);
    },
  );
  test('BIP85 and seed-viewer guards remain those of the upstream app', () {
    for (final superuser in [false, true]) {
      for (final dev in [false, true]) {
        final items = buildSettingsItems(
          localization: localization,
          isSuperuser: superuser,
          isDevModeEnabled: dev,
        );
        expect(
          items.any((item) => item.id == SettingsItemId.bip85),
          superuser && dev,
        );
        expect(
          items.any((item) => item.id == SettingsItemId.seedViewer),
          superuser,
        );
      }
    }
  });
}
