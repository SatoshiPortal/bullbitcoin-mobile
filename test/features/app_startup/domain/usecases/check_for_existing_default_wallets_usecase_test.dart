import 'dart:typed_data';

import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/check_for_existing_default_wallets_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockSeedRepository extends Mock implements SeedRepository {}

class _MockWallet extends Mock implements Wallet {}

void main() {
  test('propagates a failed default-wallet recovery', () async {
    final settings = _MockSettingsRepository();
    final wallets = _MockWalletRepository();
    final seeds = _MockSeedRepository();
    final liquidWallet = _MockWallet();
    final seed = Seed.bytes(
      bytes: Uint8List(32),
      masterFingerprint: 'aabbccdd',
    );
    when(() => settings.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
    when(() => liquidWallet.network).thenReturn(Network.liquidMainnet);
    when(
      () => liquidWallet.localMasterFingerprints,
    ).thenReturn(const ['aabbccdd']);
    when(
      () => wallets.getWallets(
        environment: Environment.mainnet,
        onlyDefaults: true,
      ),
    ).thenAnswer((_) async => [liquidWallet]);
    when(() => seeds.get('aabbccdd')).thenAnswer((_) async => seed);
    when(
      () => wallets.createWallet(
        seed: seed,
        network: Network.bitcoinMainnet,
        scriptType: ScriptType.bip84,
        isDefault: true,
      ),
    ).thenThrow(StateError('recovery failed'));
    final usecase = CheckForExistingDefaultWalletsUsecase(
      settingsRepository: settings,
      walletRepository: wallets,
      seedRepository: seeds,
    );

    await expectLater(usecase.execute(), throwsStateError);
  });
}
