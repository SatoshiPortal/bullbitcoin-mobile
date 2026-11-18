import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap_server.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_server_setting_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/swap/domain/usecases/get_swap_server_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Settings extends Mock implements SettingsRepository {}

class _Servers extends Mock implements SwapServerSettingRepository {}

void main() {
  for (final environment in Environment.values) {
    test(
      'swap server result preserves exact context ${environment.name}',
      () async {
        final settings = _Settings();
        final servers = _Servers();
        when(settings.fetch).thenAnswer(
          (_) async => SettingsEntity(
            environment: environment,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'CAD',
          ),
        );
        when(() => servers.fetch(isTestnet: any(named: 'isTestnet')))
            .thenAnswer((_) async => SwapServer.mainnetDefault);
        final result = await GetSwapServerUsecase(
          swapServerSettingRepository: servers,
          settingsRepository: settings,
        ).execute();
        // This type matcher compiles with the old bool record too, failing on
        // its lost concrete context rather than on a new member lookup.
        expect(result, isA<({SwapServer server, NetworkEnv environment})>());
        expect(result.toString(), contains(environment.networkEnv.toString()));
        if (environment == Environment.regtest) {
          verifyZeroInteractions(servers);
        }
      },
      // The regtest profile comes from the build define; without it the use
      // case refuses by design.
      skip:
          environment == Environment.regtest && !RegtestHostProfile.isConfigured
          ? 'requires --dart-define=BULL_REGTEST_HOST'
          : false,
    );
  }
}
