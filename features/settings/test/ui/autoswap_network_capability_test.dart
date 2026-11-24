import 'package:settings/testing.dart';
import 'package:settings/generated/l10n/settings_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  for (final environment in [
    NetworkEnv.mainnet,
    NetworkEnv.testnet,
    NetworkEnv.regtest,
    NetworkEnv.signet,
  ]) {
    test('automatic swap settings match support on $environment', () {
      final items = buildSettingsItems(
        localization: SettingsLocalizationsEn(),
        environment: environment,
      );
      expect(
        items.any((item) => item.id == SettingsItemId.autoswap),
        environment == NetworkEnv.mainnet || environment == NetworkEnv.testnet,
      );
      if (environment == NetworkEnv.regtest) {
        expect(
          NetworkCapabilities.supports(
            BitcoinNetwork.regtest,
            NetworkCapability.swaps,
          ),
          isTrue,
        );
        expect(
          NetworkCapabilities.supports(
            LiquidNetwork.regtest,
            NetworkCapability.swaps,
          ),
          isTrue,
        );
      }
    });
  }
}
