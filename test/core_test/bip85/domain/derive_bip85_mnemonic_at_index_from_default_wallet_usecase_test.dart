import 'dart:typed_data';

import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/bip85/domain/derive_bip85_mnemonic_at_index_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBip85Repository extends Mock implements Bip85Repository {}

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockSeedRepository extends Mock implements SeedRepository {}

void main() {
  const alias = 'Reserved product';
  const derivation = "39'/0'/12'/77'";
  final mnemonic = bip39.Mnemonic.fromWords(
    words: List.generate(11, (_) => 'zoo') + ['wrong'],
  );
  final seed = Seed.bytes(
    bytes: Uint8List.fromList(mnemonic.seed),
    masterFingerprint: 'root',
  );
  final mainnetXprv = Bip32Derivation.getXprvFromSeed(
    seed.bytes,
    Network.bitcoinMainnet,
  );

  late _MockBip85Repository bip85Repository;
  late _MockWalletRepository walletRepository;
  late _MockSeedRepository seedRepository;
  late DeriveBip85MnemonicAtIndexFromDefaultWalletUsecase usecase;

  setUp(() {
    bip85Repository = _MockBip85Repository();
    walletRepository = _MockWalletRepository();
    seedRepository = _MockSeedRepository();
    usecase = DeriveBip85MnemonicAtIndexFromDefaultWalletUsecase(
      bip85Repository: bip85Repository,
      walletRepository: walletRepository,
      seedRepository: seedRepository,
    );

    when(
      () => walletRepository.getWallets(
        environment: null,
        onlyDefaults: true,
        onlyBitcoin: true,
      ),
    ).thenAnswer((_) async => [_defaultWallet()]);
    when(() => seedRepository.get('root')).thenAnswer((_) async => seed);
    when(
      () => bip85Repository.deriveMnemonicPreview(
        xprvBase58: mainnetXprv,
        length: bip39.MnemonicLength.words12,
        index: 77,
      ),
    ).thenAnswer((_) async => Ok((derivation: derivation, mnemonic: mnemonic)));
  });

  test('derives and stores an unused fixed index', () async {
    when(
      () => bip85Repository.fetch(derivation),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => bip85Repository.deriveMnemonic(
        xprvBase58: mainnetXprv,
        length: bip39.MnemonicLength.words12,
        index: 77,
        alias: alias,
      ),
    ).thenAnswer((_) async => Ok((derivation: derivation, mnemonic: mnemonic)));

    final result = await usecase.execute(index: 77, alias: alias);

    expect(_value(result).derivation, derivation);
    verify(
      () => bip85Repository.deriveMnemonic(
        xprvBase58: mainnetXprv,
        length: bip39.MnemonicLength.words12,
        index: 77,
        alias: alias,
      ),
    ).called(1);
  });

  test('reuses a compatible fixed-index derivation', () async {
    const fingerprint = 'current-fingerprint';
    when(() => bip85Repository.fetch(derivation)).thenAnswer(
      (_) async => Ok(_derivation(alias: alias, xprvFingerprint: fingerprint)),
    );
    when(
      () => bip85Repository.fingerprintFromXprv(mainnetXprv),
    ).thenReturn(const Ok(fingerprint));

    final result = await usecase.execute(index: 77, alias: alias);

    expect(_value(result).derivation, derivation);
    verifyNever(
      () => bip85Repository.deriveMnemonic(
        xprvBase58: mainnetXprv,
        length: bip39.MnemonicLength.words12,
        index: 77,
        alias: alias,
      ),
    );
  });

  test('returns an explicit conflict for a different alias', () async {
    const fingerprint = 'current-fingerprint';
    when(() => bip85Repository.fetch(derivation)).thenAnswer(
      (_) async =>
          Ok(_derivation(alias: 'Other', xprvFingerprint: fingerprint)),
    );
    when(
      () => bip85Repository.fingerprintFromXprv(mainnetXprv),
    ).thenReturn(const Ok(fingerprint));

    final result = await usecase.execute(index: 77, alias: alias);

    expect(_failure(result), isA<Bip85DerivationConflictFailure>());
    verifyNever(
      () => bip85Repository.deriveMnemonic(
        xprvBase58: mainnetXprv,
        length: bip39.MnemonicLength.words12,
        index: 77,
        alias: alias,
      ),
    );
  });

  test('replaces a fixed-index derivation from a stale fingerprint', () async {
    when(() => bip85Repository.fetch(derivation)).thenAnswer(
      (_) async =>
          Ok(_derivation(alias: 'Old', xprvFingerprint: 'stale-fingerprint')),
    );
    when(
      () => bip85Repository.fingerprintFromXprv(mainnetXprv),
    ).thenReturn(const Ok('current-fingerprint'));
    when(
      () => bip85Repository.deriveMnemonic(
        xprvBase58: mainnetXprv,
        length: bip39.MnemonicLength.words12,
        index: 77,
        alias: alias,
      ),
    ).thenAnswer((_) async => Ok((derivation: derivation, mnemonic: mnemonic)));

    final result = await usecase.execute(index: 77, alias: alias);

    expect(_value(result).derivation, derivation);
    verify(
      () => bip85Repository.deriveMnemonic(
        xprvBase58: mainnetXprv,
        length: bip39.MnemonicLength.words12,
        index: 77,
        alias: alias,
      ),
    ).called(1);
  });

  test('returns a distinct failure when no default wallet exists', () async {
    when(
      () => walletRepository.getWallets(
        environment: null,
        onlyDefaults: true,
        onlyBitcoin: true,
      ),
    ).thenAnswer((_) async => []);

    final result = await usecase.execute(index: 77, alias: alias);

    expect(_failure(result), isA<Bip85NoDefaultWalletFailure>());
  });

  test(
    'selects the default Bitcoin wallet for the requested environment',
    () async {
      when(
        () => walletRepository.getWallets(
          environment: Environment.testnet,
          onlyDefaults: true,
          onlyBitcoin: true,
        ),
      ).thenAnswer(
        (_) async => [_defaultWallet(network: Network.bitcoinTestnet)],
      );
      final testnetXprv = Bip32Derivation.getXprvFromSeed(
        seed.bytes,
        Network.bitcoinTestnet,
      );
      when(
        () => bip85Repository.deriveMnemonicPreview(
          xprvBase58: testnetXprv,
          length: bip39.MnemonicLength.words12,
          index: 77,
        ),
      ).thenAnswer(
        (_) async => Ok((derivation: derivation, mnemonic: mnemonic)),
      );
      when(
        () => bip85Repository.fetch(derivation),
      ).thenAnswer((_) async => const Ok(null));
      when(
        () => bip85Repository.deriveMnemonic(
          xprvBase58: testnetXprv,
          length: bip39.MnemonicLength.words12,
          index: 77,
          alias: alias,
        ),
      ).thenAnswer(
        (_) async => Ok((derivation: derivation, mnemonic: mnemonic)),
      );

      final result = await usecase.execute(
        index: 77,
        alias: alias,
        environment: Environment.testnet,
      );

      expect(_value(result).derivation, derivation);
      verify(
        () => walletRepository.getWallets(
          environment: Environment.testnet,
          onlyDefaults: true,
          onlyBitcoin: true,
        ),
      ).called(1);
    },
  );

  test(
    'does not copy an unexpected exception message into the failure',
    () async {
      when(
        () => walletRepository.getWallets(
          environment: null,
          onlyDefaults: true,
          onlyBitcoin: true,
        ),
      ).thenThrow(Exception('sensitive test payload'));

      final result = await usecase.execute(index: 77, alias: alias);
      final failure = _failure(result);

      expect(failure, isA<Bip85UnexpectedFailure>());
      expect(failure.logMessage, isNot(contains('sensitive test payload')));
    },
  );
}

({String derivation, bip39.Mnemonic mnemonic}) _value(
  Result<({String derivation, bip39.Mnemonic mnemonic}), Bip85Failure> result,
) {
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => fail('Expected Ok, got ${failure.runtimeType}'),
  };
}

Bip85Failure _failure(
  Result<({String derivation, bip39.Mnemonic mnemonic}), Bip85Failure> result,
) {
  return switch (result) {
    Ok() => fail('Expected Err, got Ok'),
    Err(:final failure) => failure,
  };
}

Wallet _defaultWallet({Network network = Network.bitcoinMainnet}) {
  return Wallet(
    origin: 'default',
    label: 'Default',
    network: network,
    isDefault: true,
    masterFingerprint: 'root',
    xpubFingerprint: 'xpub',
    scriptType: ScriptType.bip84,
    xpub: 'xpub',
    externalPublicDescriptor: '',
    internalPublicDescriptor: '',
    signer: SignerEntity.local,
    signerDevice: null,
    balanceSat: BigInt.zero,
  );
}

Bip85DerivationEntity _derivation({
  required String? alias,
  required String xprvFingerprint,
}) {
  return Bip85DerivationEntity(
    path: "39'/0'/12'/77'",
    xprvFingerprint: xprvFingerprint,
    alias: alias,
    status: Bip85Status.active,
    application: Bip85Application.bip39,
    index: 77,
  );
}
