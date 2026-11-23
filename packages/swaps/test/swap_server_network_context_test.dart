import 'package:preferences/preferences.dart' as settings;
import 'package:swaps/src/swap_engine_switcher.dart';
import 'package:swaps/swaps.dart'
    show SwapServer, SwapStore, SwapsFailure, SwapsUnsupportedNetworkFailure;
import 'package:swaps/src/domain/swap_server_setting_repository.dart';
import 'package:swaps/src/domain/swap_server_control.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Settings extends Mock implements settings.Preferences {}

class _Servers extends Mock implements SwapServerSettingRepository {}

class _Switcher extends Mock implements SwapEngineSwitcher {}

class _Store extends Mock implements SwapStore {}

void main() {
  for (final environment in settings.Environment.values) {
    test(
      'swap server result preserves exact context ${environment.name}',
      () async {
        final preferences = _Settings();
        final servers = _Servers();
        when(preferences.fetch).thenAnswer(
          (_) async => Ok(
            settings.SettingsEntity(
              environment: environment,
              bitcoinUnit: BitcoinUnit.sats,
              currencyCode: 'CAD',
            ),
          ),
        );
        when(() => servers.fetch(isTestnet: any(named: 'isTestnet')))
            .thenAnswer((_) async => SwapServer.mainnetDefault);
        final result = await SwapServerControl(
          swapServerSettingRepository: servers,
          settingsRepository: preferences,
          swapEngineSwitcher: _Switcher(),
          swapStore: _Store(),
        ).readServer();
        if (environment == settings.Environment.regtest &&
            !RegtestHostProfile.isConfigured) {
          expect(
            result,
            isA<Err>().having(
              (result) => result.failure,
              'failure',
              isA<SwapsUnsupportedNetworkFailure>(),
            ),
          );
          verifyZeroInteractions(servers);
          return;
        }
        expect(
          result,
          isA<Ok<({SwapServer server, NetworkEnv environment}), SwapsFailure>>()
              .having(
                (result) => result.value.environment,
                'environment',
                environment.networkEnv,
              ),
        );
        if (environment == settings.Environment.regtest) {
          verifyZeroInteractions(servers);
        }
      },
    );
  }
}
