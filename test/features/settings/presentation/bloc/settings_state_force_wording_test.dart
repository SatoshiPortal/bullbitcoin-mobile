import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;

SettingsEntity _settings({required bool devMode}) => SettingsEntity(
  environment: Environment.mainnet,
  bitcoinUnit: BitcoinUnit.btc,
  currencyCode: 'USD',
  isDevModeEnabled: devMode,
);

void main() {
  group('SettingsState.isAppStoreWordingForced', () {
    test('needs both Dev Mode and the stored switch', () {
      final devOn = SettingsState(
        storedSettings: _settings(devMode: true),
        forceAppStoreWording: true,
      );
      expect(devOn.isAppStoreWordingForced, isTrue);

      final devOff = devOn.copyWith(storedSettings: _settings(devMode: false));
      expect(devOff.isAppStoreWordingForced, isFalse);
      expect(devOff.forceAppStoreWording, isTrue, reason: 'value is kept');

      expect(
        devOn.copyWith(forceAppStoreWording: false).isAppStoreWordingForced,
        isFalse,
      );
    });

    test('is not forced before the settings are loaded', () {
      expect(
        const SettingsState(forceAppStoreWording: true).isAppStoreWordingForced,
        isFalse,
      );
    });
  });
}
