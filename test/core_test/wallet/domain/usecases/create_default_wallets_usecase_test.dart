import 'package:bb_mobile/features/wallet/domain/default_wallet_failure.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;
import 'package:primitives/primitives.dart' show Err, Ok;

import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockWallet extends Mock implements Wallet {}

void main() {
  late Secrets secrets;
  late Secret secret;
  setUp(() async {
    FakeSecureStoragePlatform().install();
    secrets = Secrets(scratchDirectory: () async => '/tmp');
    secret = switch (await secrets.import(
      words: [...List.filled(11, 'abandon'), 'about'],
    )) {
      Ok(:final value) => value,
      Err(:final failure) => throw StateError(failure.runtimeType.toString()),
    };
  });
  test(
    'does not attempt Liquid creation when Bitcoin creation fails',
    () async {
      final settings = _MockSettingsRepository();
      final wallets = _MockWalletRepository();
      final usecase = CreateDefaultWalletsUsecase(
        secrets: secrets,
        settingsRepository: settings,
        walletRepository: wallets,
      );

      when(settings.fetch).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
      );
      when(
        () => wallets.getWallets(
          onlyDefaults: true,
          environment: Environment.mainnet,
        ),
      ).thenAnswer((_) async => Ok([]));
      when(
        () => wallets.createWallet(
          secret: secret,
          network: Network.bitcoinMainnet,
          scriptType: ScriptType.bip84,
          isDefault: true,
          birthday: any(named: 'birthday'),
        ),
      ).thenThrow(Exception('Bitcoin wallet creation failed'));

      expect(
        await usecase.execute(secret: secret),
        isA<Err<List<Wallet>, DefaultWalletFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<DefaultWalletCreationFailure>(),
        ),
      );

      verifyNever(
        () => wallets.createWallet(
          secret: secret,
          network: Network.liquidMainnet,
          scriptType: ScriptType.bip84,
          isDefault: true,
          birthday: any(named: 'birthday'),
        ),
      );
      verifyNever(() => wallets.deleteWallet(walletId: any(named: 'walletId')));
    },
  );

  test(
    'retains a newly created Bitcoin wallet when Liquid creation fails',
    () async {
      final settings = _MockSettingsRepository();
      final wallets = _MockWalletRepository();
      final liquidWallet = _MockWallet();
      final usecase = CreateDefaultWalletsUsecase(
        secrets: secrets,
        settingsRepository: settings,
        walletRepository: wallets,
      );

      when(settings.fetch).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
      );
      when(
        () => wallets.getWallets(
          onlyDefaults: true,
          environment: Environment.mainnet,
        ),
      ).thenAnswer((_) async => Ok([]));
      when(() => liquidWallet.id).thenReturn('liquid-wallet');
      when(
        () => wallets.createWallet(
          secret: secret,
          network: Network.bitcoinMainnet,
          scriptType: ScriptType.bip84,
          isDefault: true,
          birthday: any(named: 'birthday'),
        ),
      ).thenAnswer((_) async => liquidWallet);
      when(
        () => wallets.createWallet(
          secret: secret,
          network: Network.liquidMainnet,
          scriptType: ScriptType.bip84,
          isDefault: true,
          birthday: any(named: 'birthday'),
        ),
      ).thenThrow(Exception('Liquid wallet creation failed'));
      when(() => wallets.deleteWallet(walletId: 'liquid-wallet'))
          .thenAnswer((_) async => const Ok(null));

      expect(
        await usecase.execute(secret: secret),
        isA<Err<List<Wallet>, DefaultWalletFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<DefaultWalletCreationFailure>(),
        ),
      );

      verifyNever(() => wallets.deleteWallet(walletId: any(named: 'walletId')));
    },
  );
}
