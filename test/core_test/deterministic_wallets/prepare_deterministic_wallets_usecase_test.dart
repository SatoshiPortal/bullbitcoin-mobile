import 'dart:typed_data';

import 'package:bb_mobile/core/bip85/domain/derive_bip85_mnemonic_at_index_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/core/deterministic_wallets/deterministic_wallet_failure.dart';
import 'package:bb_mobile/core/deterministic_wallets/deterministic_wallets.dart';
import 'package:bb_mobile/core/deterministic_wallets/prepare_deterministic_wallets_usecase.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/failures/failure.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Derive extends Mock
    implements DeriveBip85MnemonicAtIndexFromDefaultWalletUsecase {}

class _Wallets extends Mock implements WalletRepository {}

class _Seeds extends Mock implements SeedRepository {}

const _bitcoin = DeterministicWalletSpec(
  id: 'bitcoin',
  network: Network.bitcoinMainnet,
  scriptType: ScriptType.bip84,
  label: 'Bitcoin',
  isDefault: false,
  sync: false,
);
const _liquid = DeterministicWalletSpec(
  id: 'liquid',
  network: Network.liquidMainnet,
  scriptType: ScriptType.bip84,
  label: 'Liquid',
  isDefault: false,
  sync: false,
);
const _request = DeterministicWalletsRequest(
  bip85Index: 100,
  bip85Alias: 'BTCPay',
  environment: Environment.mainnet,
  walletSpecs: [_bitcoin, _liquid],
);

void main() {
  final mnemonic = bip39.Mnemonic.fromWords(
    words: List.generate(11, (_) => 'zoo') + ['wrong'],
  );
  final fallbackSeed =
      Seed.mnemonic(
            mnemonicWords: const ['fallback'],
            bytes: Uint8List(16),
            masterFingerprint: 'fallback',
          )
          as MnemonicSeed;
  late _Derive derive;
  late _Wallets wallets;
  late _Seeds seeds;
  late PrepareDeterministicWalletsUsecase usecase;

  setUpAll(() {
    registerFallbackValue(fallbackSeed);
    registerFallbackValue(_bitcoin);
  });

  setUp(() {
    derive = _Derive();
    wallets = _Wallets();
    seeds = _Seeds();
    usecase = PrepareDeterministicWalletsUsecase(
      derive,
      walletRepository: wallets,
      seedRepository: seeds,
    );
    when(
      () => derive.execute(
        index: 100,
        alias: 'BTCPay',
        environment: Environment.mainnet,
      ),
    ).thenAnswer(
      (_) async => Ok((
        derivation: "39'/0'/12'/100'",
        mnemonic: mnemonic,
        parentFingerprint: 'aabbccdd',
      )),
    );
  });

  test('reuses matching wallets without touching the child seed', () async {
    final bitcoin = _prepared(_bitcoin, created: false);
    final liquid = _prepared(_liquid, created: false);
    when(
      () => wallets.findMatchingDeterministicWallet(
        seed: any(named: 'seed'),
        spec: _bitcoin,
      ),
    ).thenAnswer((_) async => bitcoin);
    when(
      () => wallets.findMatchingDeterministicWallet(
        seed: any(named: 'seed'),
        spec: _liquid,
      ),
    ).thenAnswer((_) async => liquid);

    final result = await usecase.execute(_request);

    expect(result, isA<Ok<dynamic, DeterministicWalletFailure>>());
    expect(_value(result).wallets, [bitcoin, liquid]);
    expect(_value(result).childSeedStoredDuringAttempt, isFalse);
    verifyNever(() => seeds.exists(any()));
    verifyNever(
      () => seeds.createFromMnemonic(
        mnemonicWords: any(named: 'mnemonicWords'),
        passphrase: any(named: 'passphrase'),
      ),
    );
  });

  test(
    'rolls back new wallets and their newly stored seed on failure',
    () async {
      when(
        () => wallets.findMatchingDeterministicWallet(
          seed: any(named: 'seed'),
          spec: any(named: 'spec'),
        ),
      ).thenAnswer((_) async => null);
      when(() => seeds.exists(any())).thenAnswer((_) async => false);
      when(
        () => seeds.createFromMnemonic(
          mnemonicWords: any(named: 'mnemonicWords'),
          passphrase: any(named: 'passphrase'),
        ),
      ).thenAnswer((_) async => fallbackSeed);
      when(
        () => wallets.createWallet(
          seed: any(named: 'seed'),
          network: _bitcoin.network,
          scriptType: _bitcoin.scriptType,
          label: _bitcoin.label,
          isDefault: _bitcoin.isDefault,
          sync: _bitcoin.sync,
        ),
      ).thenAnswer((_) async => _wallet(_bitcoin));
      when(
        () => wallets.createWallet(
          seed: any(named: 'seed'),
          network: _liquid.network,
          scriptType: _liquid.scriptType,
          label: _liquid.label,
          isDefault: _liquid.isDefault,
          sync: _liquid.sync,
        ),
      ).thenThrow(Exception('create failed'));
      when(
        () => wallets.deleteWallet(walletId: 'bitcoin-wallet'),
      ).thenAnswer((_) async {});
      when(() => seeds.delete(any())).thenAnswer((_) async => const Ok(null));

      final result = await usecase.execute(_request);

      expect(result, isA<Err<dynamic, DeterministicWalletFailure>>());
      expect(
        (result as Err).failure,
        isA<DeterministicWalletOperationFailure>(),
      );
      verify(() => wallets.deleteWallet(walletId: 'bitcoin-wallet')).called(1);
      verify(() => seeds.delete(any())).called(1);
    },
  );

  test('preserves a reserved-path conflict as a distinct failure', () async {
    when(
      () => derive.execute(
        index: 100,
        alias: 'BTCPay',
        environment: Environment.mainnet,
      ),
    ).thenAnswer((_) async => const Err(Bip85DerivationConflictFailure()));

    final result = await usecase.execute(_request);

    expect(result, isA<Err<dynamic, DeterministicWalletFailure>>());
    expect(
      (result as Err).failure,
      isA<DeterministicWalletDerivationConflictFailure>(),
    );
    verifyNever(
      () => wallets.findMatchingDeterministicWallet(
        seed: any(named: 'seed'),
        spec: any(named: 'spec'),
      ),
    );
  });
}

PreparedDeterministicWallet _prepared(
  DeterministicWalletSpec spec, {
  required bool created,
}) => PreparedDeterministicWallet(
  specId: spec.id,
  walletId: '${spec.id}-wallet',
  network: spec.network,
  scriptType: spec.scriptType,
  label: spec.label,
  externalPublicDescriptor: '${spec.id}-external',
  internalPublicDescriptor: '${spec.id}-internal',
  created: created,
);

Wallet _wallet(DeterministicWalletSpec spec) => Wallet(
  origin: '${spec.id}-wallet',
  network: spec.network,
  masterFingerprint: 'aabbccdd',
  xpubFingerprint: '11223344',
  scriptType: spec.scriptType,
  xpub: 'xpub',
  externalPublicDescriptor: '${spec.id}-external',
  internalPublicDescriptor: '${spec.id}-internal',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.zero,
);

T _value<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw TestFailure('Unexpected failure: $failure'),
};
