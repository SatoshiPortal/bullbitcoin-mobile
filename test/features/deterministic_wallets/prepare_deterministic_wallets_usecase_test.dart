import 'dart:typed_data';

import 'package:bb_mobile/core/bip85/domain/derive_bip85_mnemonic_at_index_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/core/failures/failure.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/deterministic_wallet_failure.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/deterministic_wallets.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/prepare_deterministic_wallets_usecase.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/repositories/deterministic_wallet_repository.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Derive extends Mock
    implements DeriveBip85MnemonicAtIndexFromDefaultWalletUsecase {}

class _Repository extends Mock implements DeterministicWalletRepository {}

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
  late _Derive derive;
  late _Repository repository;
  late PrepareDeterministicWalletsUsecase usecase;

  setUpAll(() {
    registerFallbackValue(
      Seed.mnemonic(
            mnemonicWords: const ['fallback'],
            bytes: Uint8List(16),
            masterFingerprint: 'fallback',
          )
          as MnemonicSeed,
    );
    registerFallbackValue(_bitcoin);
  });

  setUp(() {
    derive = _Derive();
    repository = _Repository();
    usecase = PrepareDeterministicWalletsUsecase(derive, repository);
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
      () => repository.findMatchingWallet(
        seed: any(named: 'seed'),
        spec: _bitcoin,
      ),
    ).thenAnswer((_) async => bitcoin);
    when(
      () => repository.findMatchingWallet(
        seed: any(named: 'seed'),
        spec: _liquid,
      ),
    ).thenAnswer((_) async => liquid);

    final result = await usecase.execute(_request);

    expect(result, isA<Ok<dynamic, DeterministicWalletFailure>>());
    expect(_value(result).wallets, [bitcoin, liquid]);
    expect(_value(result).childSeedStoredDuringAttempt, isFalse);
    verifyNever(() => repository.seedExists(any()));
    verifyNever(() => repository.storeSeed(any()));
  });

  test(
    'rolls back new wallets and their newly stored seed on failure',
    () async {
      final bitcoin = _prepared(_bitcoin, created: true);
      when(
        () => repository.findMatchingWallet(
          seed: any(named: 'seed'),
          spec: any(named: 'spec'),
        ),
      ).thenAnswer((_) async => null);
      when(() => repository.seedExists(any())).thenAnswer((_) async => false);
      when(() => repository.storeSeed(any())).thenAnswer((_) async {});
      when(
        () => repository.createWallet(
          seed: any(named: 'seed'),
          spec: _bitcoin,
        ),
      ).thenAnswer((_) async => bitcoin);
      when(
        () => repository.createWallet(
          seed: any(named: 'seed'),
          spec: _liquid,
        ),
      ).thenThrow(Exception('create failed'));
      when(
        () => repository.deleteWallet(bitcoin.walletId),
      ).thenAnswer((_) async {});
      when(() => repository.deleteSeed(any())).thenAnswer((_) async {});

      final result = await usecase.execute(_request);

      expect(result, isA<Err<dynamic, DeterministicWalletFailure>>());
      expect(
        (result as Err).failure,
        isA<DeterministicWalletOperationFailure>(),
      );
      verify(() => repository.storeSeed(any())).called(1);
      verify(() => repository.deleteWallet(bitcoin.walletId)).called(1);
      verify(() => repository.deleteSeed(any())).called(1);
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
      () => repository.findMatchingWallet(
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

T _value<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw TestFailure('Unexpected failure: $failure'),
};
