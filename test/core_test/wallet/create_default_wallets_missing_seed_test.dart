import 'dart:typed_data';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/data/services/mnemonic_generator.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/inconsistent_wallet_state_exception.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Seeds extends Mock implements SeedRepository {}

class _Settings extends Mock implements SettingsRepository {}

class _Mnemonic extends Mock implements MnemonicGenerator {}

class _Wallets extends Mock implements WalletRepository {}

void main() {
  const words = ['abandon', 'ability'];
  late _Seeds seeds;
  late _Wallets wallets;
  late CreateDefaultWalletsUsecase usecase;
  late List<Wallet> defaults;

  setUp(() {
    seeds = _Seeds();
    wallets = _Wallets();
    final settings = _Settings();
    defaults = [
      _wallet('bitcoin', Network.bitcoinMainnet),
      _wallet('liquid', Network.liquidMainnet),
    ];
    when(() => settings.fetch()).thenAnswer(
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
    ).thenAnswer((_) async => defaults);
    usecase = CreateDefaultWalletsUsecase(
      seedRepository: seeds,
      settingsRepository: settings,
      mnemonicGenerator: _Mnemonic(),
      walletRepository: wallets,
    );
  });

  test('fails loudly when default wallet records have no seed', () async {
    when(() => seeds.exists('aabbccdd')).thenAnswer((_) async => false);

    await expectLater(
      usecase.execute(),
      throwsA(
        isA<InconsistentWalletStateException>().having(
          (error) => error.fingerprint,
          'fingerprint',
          'aabbccdd',
        ),
      ),
    );
    verify(
      () => wallets.getWallets(
        onlyDefaults: true,
        environment: Environment.mainnet,
      ),
    ).called(1);
    verifyNoMoreInteractions(wallets);
  });

  test('restores a matching supplied seed before returning defaults', () async {
    final restored =
        Seed.mnemonic(
              mnemonicWords: words,
              bytes: Uint8List(16),
              masterFingerprint: 'aabbccdd',
            )
            as MnemonicSeed;
    when(() => seeds.exists('aabbccdd')).thenAnswer((_) async => false);
    when(
      () => seeds.fingerprintFor(mnemonicWords: words, passphrase: null),
    ).thenReturn('aabbccdd');
    when(
      () => seeds.createFromMnemonic(mnemonicWords: words, passphrase: null),
    ).thenAnswer((_) async => restored);

    final result = await usecase.execute(mnemonicWords: words);

    expect(result, defaults);
    verify(
      () => seeds.createFromMnemonic(mnemonicWords: words, passphrase: null),
    ).called(1);
  });
}

Wallet _wallet(String id, Network network) => Wallet(
  origin: id,
  network: network,
  isDefault: true,
  masterFingerprint: 'aabbccdd',
  xpubFingerprint: '11223344',
  scriptType: ScriptType.bip84,
  xpub: 'xpub',
  externalPublicDescriptor: 'external',
  internalPublicDescriptor: 'internal',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.zero,
);
