import 'package:bb_mobile/features/keychain_manifest/keychain_manifest_locator.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bb_mobile/features/settings/ui/settings_item.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

class _Settings extends Fake implements SettingsFacade {
  final entries = <SettingsEntryContribution>[];

  @override
  void registerEntry(SettingsEntryContribution contribution) =>
      entries.add(contribution);
}

void main() {
  test('the production Nostr entry is registered under Tools', () async {
    final locator = GetIt.asNewInstance();
    addTearDown(locator.reset);
    final settings = _Settings();
    locator.registerSingleton<SettingsFacade>(settings);
    KeychainManifestLocator.setup(locator);
    final contribution = settings.entries.single;
    expect(contribution.id, 'nostr-keys');
    expect(contribution.section.name, 'tools');
    final item = buildSettingsItems(
      localization: AppLocalizationsEn(),
      contributions: settings.entries,
    ).byId(SettingsItemId.extension);
    expect(item.section, SettingsItemSection.tools);
    expect(item.path, ['Settings', 'Tools', item.title]);
  });
}
