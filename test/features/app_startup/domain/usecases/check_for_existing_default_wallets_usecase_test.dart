import 'package:primitives/primitives.dart' show BitcoinUnit;
import 'package:primitives/primitives.dart' show Ok;
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/app_startup/domain/app_startup_failure.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/check_for_existing_default_wallets_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockWallet extends Mock implements Wallet {}

void main() {
  test(
    'a failed default-wallet heal retains access to the existing secret',
    () async {
      final settings = _MockSettingsRepository();
      final wallets = _MockWalletRepository();
      FakeSecureStoragePlatform().install();
      final secrets = Secrets(scratchDirectory: () async => '/tmp');
      final result = await secrets.import(
        words: [...List.filled(11, 'abandon'), 'about'],
      );
      final secret = (result as Ok<Secret, SecretFailure>).value;
      registerFallbackValue(secret);
      final liquidWallet = _MockWallet();
      when(() => settings.fetch()).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
      );
      when(() => liquidWallet.network).thenReturn(Network.liquidMainnet);
      when(
        () => liquidWallet.localSeedFingerprints,
      ).thenReturn([secret.id.hex]);
      when(
        () => wallets.getWallets(
          environment: Environment.mainnet,
          onlyDefaults: true,
        ),
      ).thenAnswer((_) async => Ok([liquidWallet]));
      when(
        () => wallets.createWallet(
          secret: any(named: 'secret'),
          network: Network.bitcoinMainnet,
          scriptType: ScriptType.bip84,
          isDefault: true,
        ),
      ).thenThrow(StateError('recovery failed'));
      final usecase = CheckForExistingDefaultWalletsUsecase(
        settingsRepository: settings,
        walletRepository: wallets,
        secrets: secrets,
      );

      expect(
        await usecase.execute(),
        isA<Ok<bool, AppStartupFailure>>().having(
          (result) => result.value,
          'value',
          isTrue,
        ),
      );
    },
  );
}
