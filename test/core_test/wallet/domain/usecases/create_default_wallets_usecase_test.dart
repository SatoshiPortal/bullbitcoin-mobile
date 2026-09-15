import 'dart:typed_data';

import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/data/services/mnemonic_generator.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSeedRepository extends Mock implements SeedRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockMnemonicGenerator extends Mock implements MnemonicGenerator {}

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockWallet extends Mock implements Wallet {}

void main() {
  for (final adoptedBitcoin in [false, true]) {
    test(
      'reports only newly stored defaults (adopted Bitcoin: $adoptedBitcoin)',
      () async {
        final seeds = _MockSeedRepository();
        final settings = _MockSettingsRepository();
        final wallets = _MockWalletRepository();
        final bitcoin = _MockWallet();
        final liquid = _MockWallet();
        final seed = MnemonicSeed(
          mnemonicWords: const ['abandon'],
          bytes: Uint8List(32),
          masterFingerprint: 'aabbccdd',
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
        ).thenAnswer((_) async => []);
        when(wallets.getStoredWalletIds).thenAnswer(
          (_) async => {
            'unrelated-hidden-wallet',
            if (adoptedBitcoin) 'bitcoin',
          },
        );
        when(
          () => seeds.createFromMnemonic(mnemonicWords: seed.mnemonicWords),
        ).thenAnswer((_) async => seed);
        when(() => bitcoin.id).thenReturn('bitcoin');
        when(() => liquid.id).thenReturn('liquid');
        when(() => bitcoin.label).thenReturn('Initial Bitcoin');
        when(() => liquid.label).thenReturn('Initial Liquid');
        for (final entry in {
          Network.bitcoinMainnet: bitcoin,
          Network.liquidMainnet: liquid,
        }.entries) {
          when(
            () => wallets.createWallet(
              seed: seed,
              network: entry.key,
              scriptType: ScriptType.bip84,
              isDefault: true,
              provenance: WalletProvenance.defaultSeed,
              birthday: null,
            ),
          ).thenAnswer((_) async => entry.value);
        }
        final result = await CreateDefaultWalletsUsecase(
          seedRepository: seeds,
          settingsRepository: settings,
          mnemonicGenerator: _MockMnemonicGenerator(),
          walletRepository: wallets,
        ).execute(mnemonicWords: seed.mnemonicWords);

        expect(result.wallets, [liquid, bitcoin]);
        expect(result.createdWalletIds, {
          'liquid',
          if (!adoptedBitcoin) 'bitcoin',
        });
        expect(
          result.createdWalletPreferences.map(
            (item) => (
              item.walletRef,
              item.label,
              item.hideOnHome,
              item.autoSweepEnabled,
            ),
          ),
          [
            ('liquid', 'Initial Liquid', null, null),
            if (!adoptedBitcoin) ('bitcoin', 'Initial Bitcoin', null, null),
          ],
        );
        verify(wallets.getStoredWalletIds).called(1);
        verifyNever(
          () => wallets.deleteWallet(walletId: any(named: 'walletId')),
        );
      },
    );
  }

  test('existing defaults are not reported as created', () async {
    final seeds = _MockSeedRepository();
    final settings = _MockSettingsRepository();
    final wallets = _MockWalletRepository();
    final bitcoin = _MockWallet();
    final liquid = _MockWallet();
    when(() => bitcoin.network).thenReturn(Network.bitcoinMainnet);
    when(() => liquid.network).thenReturn(Network.liquidMainnet);
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
    ).thenAnswer((_) async => [bitcoin, liquid]);
    final result = await CreateDefaultWalletsUsecase(
      seedRepository: seeds,
      settingsRepository: settings,
      mnemonicGenerator: _MockMnemonicGenerator(),
      walletRepository: wallets,
    ).execute(mnemonicWords: const ['abandon']);
    expect(result.wallets, [bitcoin, liquid]);
    expect(result.createdWalletIds, isEmpty);
    expect(result.createdWalletPreferences, isEmpty);
    verifyNever(wallets.getStoredWalletIds);
    verifyZeroInteractions(seeds);
  });

  test(
    'does not attempt Bitcoin creation when Liquid creation fails',
    () async {
      final seeds = _MockSeedRepository();
      final settings = _MockSettingsRepository();
      final mnemonics = _MockMnemonicGenerator();
      final wallets = _MockWalletRepository();
      when(wallets.getStoredWalletIds).thenAnswer((_) async => {});
      final seed = MnemonicSeed(
        mnemonicWords: const ['abandon'],
        bytes: Uint8List(32),
        masterFingerprint: 'aabbccdd',
      );
      final usecase = CreateDefaultWalletsUsecase(
        seedRepository: seeds,
        settingsRepository: settings,
        mnemonicGenerator: mnemonics,
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
      ).thenAnswer((_) async => []);
      when(
        () => seeds.createFromMnemonic(
          mnemonicWords: any(named: 'mnemonicWords'),
          passphrase: any(named: 'passphrase'),
        ),
      ).thenAnswer((_) async => seed);
      when(
        () => wallets.createWallet(
          seed: seed,
          network: Network.liquidMainnet,
          scriptType: ScriptType.bip84,
          isDefault: true,
          provenance: WalletProvenance.defaultSeed,
          birthday: any(named: 'birthday'),
        ),
      ).thenThrow(Exception('Liquid wallet creation failed'));

      await expectLater(
        usecase.execute(mnemonicWords: seed.mnemonicWords),
        throwsA(isA<CreateDefaultWalletsException>()),
      );

      verifyNever(
        () => wallets.createWallet(
          seed: seed,
          network: Network.bitcoinMainnet,
          scriptType: ScriptType.bip84,
          isDefault: true,
          provenance: WalletProvenance.defaultSeed,
          birthday: any(named: 'birthday'),
        ),
      );
      verifyNever(() => wallets.deleteWallet(walletId: any(named: 'walletId')));
    },
  );

  test(
    'deletes a newly created Liquid wallet when Bitcoin creation fails',
    () async {
      final seeds = _MockSeedRepository();
      final settings = _MockSettingsRepository();
      final mnemonics = _MockMnemonicGenerator();
      final wallets = _MockWalletRepository();
      when(wallets.getStoredWalletIds).thenAnswer((_) async => {});
      final liquidWallet = _MockWallet();
      final seed = MnemonicSeed(
        mnemonicWords: const ['abandon'],
        bytes: Uint8List(32),
        masterFingerprint: 'aabbccdd',
      );
      final usecase = CreateDefaultWalletsUsecase(
        seedRepository: seeds,
        settingsRepository: settings,
        mnemonicGenerator: mnemonics,
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
      ).thenAnswer((_) async => []);
      when(
        () => seeds.createFromMnemonic(
          mnemonicWords: any(named: 'mnemonicWords'),
          passphrase: any(named: 'passphrase'),
        ),
      ).thenAnswer((_) async => seed);
      when(() => liquidWallet.id).thenReturn('liquid-wallet');
      when(
        () => wallets.createWallet(
          seed: seed,
          network: Network.liquidMainnet,
          scriptType: ScriptType.bip84,
          isDefault: true,
          provenance: WalletProvenance.defaultSeed,
          birthday: any(named: 'birthday'),
        ),
      ).thenAnswer((_) async => liquidWallet);
      when(
        () => wallets.createWallet(
          seed: seed,
          network: Network.bitcoinMainnet,
          scriptType: ScriptType.bip84,
          isDefault: true,
          provenance: WalletProvenance.defaultSeed,
          birthday: any(named: 'birthday'),
        ),
      ).thenThrow(Exception('Bitcoin wallet creation failed'));
      when(
        () => wallets.deleteWallet(walletId: 'liquid-wallet'),
      ).thenAnswer((_) async {});

      await expectLater(
        usecase.execute(mnemonicWords: seed.mnemonicWords),
        throwsA(isA<CreateDefaultWalletsException>()),
      );

      verify(() => wallets.deleteWallet(walletId: 'liquid-wallet')).called(1);
    },
  );
}
