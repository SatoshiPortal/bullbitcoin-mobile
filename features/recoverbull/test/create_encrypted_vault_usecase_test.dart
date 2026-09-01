import 'dart:typed_data';

import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:bull_recoverbull/src/domain/entities/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/entities/recoverbull_network.dart';
import 'package:bull_recoverbull/src/domain/entities/recoverbull_seed_material.dart';
import 'package:bull_recoverbull/src/domain/entities/recoverbull_wallet.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_seed_port.dart';
import 'package:bull_recoverbull/src/domain/repositories/recoverbull_wallet_repository.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/domain/repositories/recoverbull_repository.dart';
import 'package:bull_recoverbull/src/domain/usecases/create_encrypted_vault_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockRecoverBullRepository extends Mock
    implements RecoverBullRepository {}

class _MockSeedPort extends Mock implements RecoverBullSeedPort {}

class _MockWalletRepository extends Mock
    implements RecoverBullWalletRepository {}

class _MockEncryptedVault extends Mock implements EncryptedVault {}

void main() {
  final mnemonic = Mnemonic.fromWords(
    words: List.generate(11, (index) => 'zoo') + ['wrong'],
  );
  final seed = Uint8List.fromList(mnemonic.seed);
  final wallet = RecoverBullWallet(
    id: 'testnet-wallet',
    masterFingerprint: 'deadbeef',
    network: RecoverBullNetwork.testnet,
    isPhysicalBackupTested: false,
  );
  final mainnetWallet = RecoverBullWallet(
    id: 'mainnet-wallet',
    masterFingerprint: 'deadbeef',
    network: RecoverBullNetwork.mainnet,
    isPhysicalBackupTested: false,
  );

  late _MockRecoverBullRepository recoverBullRepository;
  late _MockSeedPort seedPort;
  late _MockWalletRepository walletRepository;

  setUp(() {
    recoverBullRepository = _MockRecoverBullRepository();
    seedPort = _MockSeedPort();
    walletRepository = _MockWalletRepository();
    when(
      () => walletRepository.getWallets(onlyBitcoin: true, onlyDefaults: true),
    ).thenAnswer((_) async => [wallet]);
    when(() => seedPort.getSeed(wallet.masterFingerprint)).thenAnswer(
      (_) async =>
          RecoverBullSeedMaterial(bytes: seed, mnemonicWords: mnemonic.words),
    );
  });

  test('testnet seed creates an encrypted vault', () async {
    final vault = _MockEncryptedVault();
    when(
      () => recoverBullRepository.createVault(
        rootXprv: any(named: 'rootXprv'),
        plaintext: any(named: 'plaintext'),
        derivationPath: any(named: 'derivationPath'),
      ),
    ).thenAnswer((_) async => Ok((vault: vault, vaultKey: '00')));

    final usecase = CreateEncryptedVaultUsecase(
      recoverBullRepository: recoverBullRepository,
      seedRepository: seedPort,
      walletRepository: walletRepository,
    );

    final result = await usecase.execute();

    expect(result, isA<Ok>());
    verify(
      () => recoverBullRepository.createVault(
        rootXprv: any(named: 'rootXprv'),
        plaintext: any(named: 'plaintext'),
        derivationPath: any(named: 'derivationPath'),
      ),
    ).called(1);
  });

  test('mainnet seed also creates an encrypted vault', () async {
    when(
      () => walletRepository.getWallets(onlyBitcoin: true, onlyDefaults: true),
    ).thenAnswer((_) async => [mainnetWallet]);
    final vault = _MockEncryptedVault();
    when(
      () => recoverBullRepository.createVault(
        rootXprv: any(named: 'rootXprv'),
        plaintext: any(named: 'plaintext'),
        derivationPath: any(named: 'derivationPath'),
      ),
    ).thenAnswer((_) async => Ok((vault: vault, vaultKey: '00')));
    final usecase = CreateEncryptedVaultUsecase(
      recoverBullRepository: recoverBullRepository,
      seedRepository: seedPort,
      walletRepository: walletRepository,
    );

    final result = await usecase.execute();

    expect(result, isA<Ok>());
    verify(
      () => recoverBullRepository.createVault(
        rootXprv: any(named: 'rootXprv'),
        plaintext: any(named: 'plaintext'),
        derivationPath: any(named: 'derivationPath'),
      ),
    ).called(1);
  });

  test('repository failure is returned without a partial vault', () async {
    const failure = RecoverBullUnexpectedFailure('expected failure');
    when(
      () => recoverBullRepository.createVault(
        rootXprv: any(named: 'rootXprv'),
        plaintext: any(named: 'plaintext'),
        derivationPath: any(named: 'derivationPath'),
      ),
    ).thenAnswer((_) async => const Err(failure));
    final usecase = CreateEncryptedVaultUsecase(
      recoverBullRepository: recoverBullRepository,
      seedRepository: seedPort,
      walletRepository: walletRepository,
    );

    final result = await usecase.execute();

    expect(
      result,
      isA<Err<({EncryptedVault vault, String vaultKey}), RecoverBullFailure>>(),
    );
    expect(
      (result
              as Err<
                ({EncryptedVault vault, String vaultKey}),
                RecoverBullFailure
              >)
          .failure,
      same(failure),
    );
  });

  for (final invalidMnemonic in <List<String>>[
    const [],
    ['not', 'a', 'mnemonic'],
  ]) {
    test(
      '${invalidMnemonic.isEmpty ? 'empty' : 'non-mnemonic'} seed returns an error before encryption',
      () async {
        when(() => seedPort.getSeed(wallet.masterFingerprint)).thenAnswer(
          (_) async => RecoverBullSeedMaterial(
            bytes: seed,
            mnemonicWords: invalidMnemonic,
          ),
        );
        final usecase = CreateEncryptedVaultUsecase(
          recoverBullRepository: recoverBullRepository,
          seedRepository: seedPort,
          walletRepository: walletRepository,
        );

        final result = await usecase.execute();

        expect(result, isA<Err>());
        verifyNever(
          () => recoverBullRepository.createVault(
            rootXprv: any(named: 'rootXprv'),
            plaintext: any(named: 'plaintext'),
            derivationPath: any(named: 'derivationPath'),
          ),
        );
      },
    );
  }
}
