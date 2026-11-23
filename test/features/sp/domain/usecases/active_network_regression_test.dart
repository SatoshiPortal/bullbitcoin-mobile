import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/usecases/create_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/scan_sp_wallet_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

import '../../sp_fakes.dart';

class _Settings extends Mock implements Preferences {}

void main() {
  for (final active in [Environment.mainnet, Environment.testnet]) {
    test(
      'create refuses a different network from active ${active.name}',
      () async {
        final requested = active == Environment.mainnet
            ? BitcoinNetwork.testnet
            : BitcoinNetwork.mainnet;
        final settings = _Settings();
        when(() => settings.fetch()).thenAnswer(
          (_) async => Ok(
            SettingsEntity(
              environment: active,
              bitcoinUnit: BitcoinUnit.sats,
              currencyCode: 'CAD',
              isSuperuser: true,
              isDevModeEnabled: true,
            ),
          ),
        );
        final secret = MockGetSpSecretUsecase();
        when(() => secret.execute(requested)).thenAnswer(
          (_) async => const Err(SpUnexpected('Custody must not be reached')),
        );
        final account = FakeSpAccountRepository(hasSessionValue: false);
        final config = FakeSpBackendConfigRepository();
        final usecase = CreateSpWalletUsecase(
          getSpSecretUsecase: secret,
          settingsRepository: settings,
          repository: account,
          files: account,
          configRepository: config,
          scanSpWalletUsecase: ScanSpWalletUsecase(
            getSpFeatureGateUsecase: FakeSpFeatureGateUsecase(),
            repository: account,
          ),
        );

        final result = await usecase.execute(
          network: requested,
          blindbitUrl: 'https://blindbit.example',
          electrumUrl: 'ssl://electrum.example:50002',
          scanFromNow: false,
        );

        expect(result, isA<Err<void, SpFailure>>());
        expect((result as Err).failure, isA<SpUnsupportedNetwork>());
        verifyNever(() => secret.execute(requested));
        expect(account.createCount, 0);
        expect((await config.fetch() as Ok).value, isNull);
      },
    );
  }
}
