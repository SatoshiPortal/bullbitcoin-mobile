import 'dart:typed_data';

import 'package:bb_mobile/core/bip85/domain/derive_bip85_mnemonic_at_index_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/deterministic_wallet_failure.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/deterministic_wallet_seed_material.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/deterministic_wallets.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/prepare_deterministic_wallets_usecase.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/repositories/deterministic_wallet_repository.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDeriveBip85MnemonicAtIndexUsecase extends Mock
    implements DeriveBip85MnemonicAtIndexFromDefaultWalletUsecase {}

class _MockDeterministicWalletRepository extends Mock
    implements DeterministicWalletRepository {}

const _bitcoinSpec = DeterministicWalletSpec(
  id: 'product-bitcoin',
  network: Network.bitcoinMainnet,
  scriptType: ScriptType.bip84,
  label: 'Product Bitcoin',
  isDefault: false,
  sync: false,
);

const _liquidSpec = DeterministicWalletSpec(
  id: 'product-liquid',
  network: Network.liquidMainnet,
  scriptType: ScriptType.bip84,
  label: 'Product Liquid',
  isDefault: false,
  sync: false,
);

const _request = DeterministicWalletsRequest(
  bip85Index: 100,
  bip85Alias: 'Product Wallets',
  environment: Environment.mainnet,
  walletSpecs: [_bitcoinSpec, _liquidSpec],
);

void main() {
  final mnemonic = bip39.Mnemonic.fromWords(
    words: List.generate(11, (_) => 'zoo') + ['wrong'],
  );

  late _MockDeriveBip85MnemonicAtIndexUsecase deriveBip85;
  late _MockDeterministicWalletRepository repository;
  late PrepareDeterministicWalletsUsecase usecase;

  setUpAll(() {
    registerFallbackValue(
      DeterministicWalletSeedMaterial(
        mnemonicWords: const ['fallback'],
        seedBytes: Uint8List.fromList(const [0]),
        masterFingerprint: 'fallback',
      ),
    );
    registerFallbackValue(_bitcoinSpec);
  });

  setUp(() {
    deriveBip85 = _MockDeriveBip85MnemonicAtIndexUsecase();
    repository = _MockDeterministicWalletRepository();
    usecase = PrepareDeterministicWalletsUsecase(
      deriveBip85: deriveBip85,
      walletRepository: repository,
    );

    when(
      () => deriveBip85.execute(
        index: _request.bip85Index,
        alias: _request.bip85Alias,
        environment: _request.environment,
      ),
    ).thenAnswer(
      (_) async => Ok((derivation: "39'/0'/12'/100'", mnemonic: mnemonic)),
    );
  });

  void stubMatch(
    DeterministicWalletSpec spec,
    Result<PreparedDeterministicWallet?, DeterministicWalletFailure> result,
  ) {
    when(
      () => repository.getMatchingWallet(
        seedMaterial: any(named: 'seedMaterial'),
        spec: spec,
      ),
    ).thenAnswer((_) async => result);
  }

  void stubSeedExists(bool exists) {
    when(
      () => repository.childSeedExists(any()),
    ).thenAnswer((_) async => Ok(exists));
  }

  void stubStoreSeed() {
    when(
      () => repository.storeChildSeed(any()),
    ).thenAnswer((_) async => const Ok(null));
  }

  void stubCreate(
    DeterministicWalletSpec spec,
    Result<PreparedDeterministicWallet, DeterministicWalletFailure> result,
  ) {
    when(
      () => repository.createWallet(
        seedMaterial: any(named: 'seedMaterial'),
        spec: spec,
      ),
    ).thenAnswer((_) async => result);
  }

  void stubDeleteWallet(
    String walletId, {
    Result<void, DeterministicWalletFailure> result = const Ok(null),
  }) {
    when(
      () => repository.deleteWallet(walletId),
    ).thenAnswer((_) async => result);
  }

  void stubDeleteSeed({
    Result<void, DeterministicWalletFailure> result = const Ok(null),
  }) {
    when(
      () => repository.deleteChildSeed(any()),
    ).thenAnswer((_) async => result);
  }

  group('request validation', () {
    final invalidRequests = <String, DeterministicWalletsRequest>{
      'negative BIP85 index': const DeterministicWalletsRequest(
        bip85Index: -1,
        bip85Alias: 'Product Wallets',
        environment: Environment.mainnet,
        walletSpecs: [_bitcoinSpec],
      ),
      'blank BIP85 alias': const DeterministicWalletsRequest(
        bip85Index: 100,
        bip85Alias: '   ',
        environment: Environment.mainnet,
        walletSpecs: [_bitcoinSpec],
      ),
      'empty wallet specs': const DeterministicWalletsRequest(
        bip85Index: 100,
        bip85Alias: 'Product Wallets',
        environment: Environment.mainnet,
        walletSpecs: [],
      ),
      'blank wallet spec id': const DeterministicWalletsRequest(
        bip85Index: 100,
        bip85Alias: 'Product Wallets',
        environment: Environment.mainnet,
        walletSpecs: [
          DeterministicWalletSpec(
            id: ' ',
            network: Network.bitcoinMainnet,
            scriptType: ScriptType.bip84,
            isDefault: false,
            sync: false,
          ),
        ],
      ),
      'duplicate wallet spec ids': const DeterministicWalletsRequest(
        bip85Index: 100,
        bip85Alias: 'Product Wallets',
        environment: Environment.mainnet,
        walletSpecs: [_bitcoinSpec, _bitcoinSpec],
      ),
    };

    for (final entry in invalidRequests.entries) {
      test('rejects ${entry.key} before deriving', () async {
        final result = await usecase.execute(entry.value);

        expect(
          _failureOf(result),
          isA<InvalidDeterministicWalletRequestFailure>(),
        );
        verifyNever(
          () => deriveBip85.execute(
            index: any(named: 'index'),
            alias: any(named: 'alias'),
            environment: any(named: 'environment'),
          ),
        );
      });
    }
  });

  test('maps a BIP85 reservation conflict into the feature failure', () async {
    when(
      () => deriveBip85.execute(
        index: _request.bip85Index,
        alias: _request.bip85Alias,
        environment: _request.environment,
      ),
    ).thenAnswer((_) async => const Err(Bip85DerivationConflictFailure()));

    final result = await usecase.execute(_request);

    expect(
      _failureOf(result),
      isA<DeterministicWalletDerivationConflictFailure>(),
    );
    verifyNever(
      () => repository.getMatchingWallet(
        seedMaterial: any(named: 'seedMaterial'),
        spec: any(named: 'spec'),
      ),
    );
  });

  test('maps other BIP85 failures into derivation failure', () async {
    when(
      () => deriveBip85.execute(
        index: _request.bip85Index,
        alias: _request.bip85Alias,
        environment: _request.environment,
      ),
    ).thenAnswer((_) async => const Err(Bip85StorageFailure()));

    final result = await usecase.execute(_request);

    expect(_failureOf(result), isA<DeterministicWalletDerivationFailure>());
  });

  test('idempotently reuses all matching wallets', () async {
    final bitcoin = _prepared(_bitcoinSpec, created: false);
    final liquid = _prepared(_liquidSpec, created: false);
    stubMatch(_bitcoinSpec, Ok(bitcoin));
    stubMatch(_liquidSpec, Ok(liquid));

    final result = await usecase.execute(_request);
    final prepared = _valueOf(result);

    expect(prepared.wallets, [bitcoin, liquid]);
    expect(prepared.childSeedStoredDuringAttempt, isFalse);
    expect(prepared.shouldDeleteChildSeedOnRollback, isFalse);
    verifyNever(() => repository.childSeedExists(any()));
    verifyNever(() => repository.storeChildSeed(any()));
    verifyNever(
      () => repository.createWallet(
        seedMaterial: any(named: 'seedMaterial'),
        spec: any(named: 'spec'),
      ),
    );
  });

  test(
    'returns a mixed reused/created result and stores the seed once',
    () async {
      final reused = _prepared(_bitcoinSpec, created: false);
      final created = _prepared(_liquidSpec, created: true);
      stubMatch(_bitcoinSpec, Ok(reused));
      stubMatch(_liquidSpec, const Ok(null));
      stubSeedExists(false);
      stubStoreSeed();
      stubCreate(_liquidSpec, Ok(created));

      final result = await usecase.execute(_request);
      final prepared = _valueOf(result);

      expect(prepared.wallets, [reused, created]);
      expect(prepared.childSeedStoredDuringAttempt, isTrue);
      expect(prepared.shouldDeleteChildSeedOnRollback, isFalse);
      verify(() => repository.storeChildSeed(any())).called(1);
      verify(
        () => repository.createWallet(
          seedMaterial: any(named: 'seedMaterial'),
          spec: _liquidSpec,
        ),
      ).called(1);
    },
  );

  test(
    'automatic rollback deletes created wallets and a seed stored by the attempt',
    () async {
      final bitcoin = _prepared(_bitcoinSpec, created: true);
      stubMatch(_bitcoinSpec, const Ok(null));
      stubMatch(_liquidSpec, const Ok(null));
      stubSeedExists(false);
      stubStoreSeed();
      stubCreate(_bitcoinSpec, Ok(bitcoin));
      stubCreate(_liquidSpec, const Err(DeterministicWalletOperationFailure()));
      stubDeleteWallet(bitcoin.walletId);
      stubDeleteSeed();

      final result = await usecase.execute(_request);

      expect(_failureOf(result), isA<DeterministicWalletOperationFailure>());
      verify(() => repository.deleteWallet(bitcoin.walletId)).called(1);
      verify(() => repository.deleteChildSeed(any())).called(1);
    },
  );

  test('automatic rollback retains a seed that predated the attempt', () async {
    stubMatch(_bitcoinSpec, const Ok(null));
    stubSeedExists(true);
    stubCreate(_bitcoinSpec, const Err(DeterministicWalletOperationFailure()));

    final result = await usecase.execute(
      const DeterministicWalletsRequest(
        bip85Index: 100,
        bip85Alias: 'Product Wallets',
        environment: Environment.mainnet,
        walletSpecs: [_bitcoinSpec],
      ),
    );

    expect(_failureOf(result), isA<DeterministicWalletOperationFailure>());
    verifyNever(() => repository.storeChildSeed(any()));
    verifyNever(() => repository.deleteChildSeed(any()));
  });

  test(
    'automatic rollback retains the seed when any wallet was reused',
    () async {
      final reused = _prepared(_bitcoinSpec, created: false);
      stubMatch(_bitcoinSpec, Ok(reused));
      stubMatch(_liquidSpec, const Ok(null));
      stubSeedExists(false);
      stubStoreSeed();
      stubCreate(_liquidSpec, const Err(DeterministicWalletOperationFailure()));

      final result = await usecase.execute(_request);

      expect(_failureOf(result), isA<DeterministicWalletOperationFailure>());
      verifyNever(() => repository.deleteChildSeed(any()));
    },
  );

  test(
    'automatic rollback retains the seed and reports rollback failure when wallet cleanup fails',
    () async {
      final bitcoin = _prepared(_bitcoinSpec, created: true);
      stubMatch(_bitcoinSpec, const Ok(null));
      stubMatch(_liquidSpec, const Ok(null));
      stubSeedExists(false);
      stubStoreSeed();
      stubCreate(_bitcoinSpec, Ok(bitcoin));
      stubCreate(_liquidSpec, const Err(DeterministicWalletOperationFailure()));
      stubDeleteWallet(
        bitcoin.walletId,
        result: const Err(DeterministicWalletRollbackFailure()),
      );

      final result = await usecase.execute(_request);

      expect(_failureOf(result), isA<DeterministicWalletRollbackFailure>());
      verifyNever(() => repository.deleteChildSeed(any()));
    },
  );

  test('automatic rollback reports a child-seed deletion failure', () async {
    stubMatch(_bitcoinSpec, const Ok(null));
    stubSeedExists(false);
    stubStoreSeed();
    stubCreate(_bitcoinSpec, const Err(DeterministicWalletOperationFailure()));
    stubDeleteSeed(result: const Err(DeterministicWalletRollbackFailure()));

    final result = await usecase.execute(
      const DeterministicWalletsRequest(
        bip85Index: 100,
        bip85Alias: 'Product Wallets',
        environment: Environment.mainnet,
        walletSpecs: [_bitcoinSpec],
      ),
    );

    expect(_failureOf(result), isA<DeterministicWalletRollbackFailure>());
  });

  test(
    'a failed seed-store completion still attempts seed cleanup for an uncertain commit',
    () async {
      stubMatch(_bitcoinSpec, const Ok(null));
      stubSeedExists(false);
      when(
        () => repository.storeChildSeed(any()),
      ).thenAnswer((_) async => const Err(DeterministicWalletStorageFailure()));
      stubDeleteSeed();

      final result = await usecase.execute(
        const DeterministicWalletsRequest(
          bip85Index: 100,
          bip85Alias: 'Product Wallets',
          environment: Environment.mainnet,
          walletSpecs: [_bitcoinSpec],
        ),
      );

      expect(_failureOf(result), isA<DeterministicWalletStorageFailure>());
      verify(() => repository.deleteChildSeed(any())).called(1);
    },
  );

  group('explicit rollback', () {
    test(
      'deletes only created wallets and then the attempt-owned seed',
      () async {
        final bitcoin = _prepared(_bitcoinSpec, created: true);
        final liquid = _prepared(_liquidSpec, created: true);
        stubDeleteWallet(bitcoin.walletId);
        stubDeleteWallet(liquid.walletId);
        stubDeleteSeed();
        final prepared = PreparedDeterministicWallets(
          wallets: [bitcoin, liquid],
          childSeedFingerprint: '3f635a63',
          childSeedStoredDuringAttempt: true,
        );

        final result = await usecase.rollbackCreatedWallets(prepared);

        expect(result, isA<Ok<void, DeterministicWalletFailure>>());
        verify(() => repository.deleteWallet(bitcoin.walletId)).called(1);
        verify(() => repository.deleteWallet(liquid.walletId)).called(1);
        verify(() => repository.deleteChildSeed('3f635a63')).called(1);
      },
    );

    test('retains the seed when the result contains a reused wallet', () async {
      final reused = _prepared(_bitcoinSpec, created: false);
      final created = _prepared(_liquidSpec, created: true);
      stubDeleteWallet(created.walletId);
      final prepared = PreparedDeterministicWallets(
        wallets: [reused, created],
        childSeedFingerprint: '3f635a63',
        childSeedStoredDuringAttempt: true,
      );

      final result = await usecase.rollbackCreatedWallets(prepared);

      expect(result, isA<Ok<void, DeterministicWalletFailure>>());
      verifyNever(() => repository.deleteWallet(reused.walletId));
      verify(() => repository.deleteWallet(created.walletId)).called(1);
      verifyNever(() => repository.deleteChildSeed(any()));
    });

    test('retains the seed when wallet deletion fails', () async {
      final created = _prepared(_bitcoinSpec, created: true);
      stubDeleteWallet(
        created.walletId,
        result: const Err(DeterministicWalletRollbackFailure()),
      );
      final prepared = PreparedDeterministicWallets(
        wallets: [created],
        childSeedFingerprint: '3f635a63',
        childSeedStoredDuringAttempt: true,
      );

      final result = await usecase.rollbackCreatedWallets(prepared);

      expect(_failureOf(result), isA<DeterministicWalletRollbackFailure>());
      verifyNever(() => repository.deleteChildSeed(any()));
    });

    test('reports child-seed deletion failure', () async {
      final created = _prepared(_bitcoinSpec, created: true);
      stubDeleteWallet(created.walletId);
      stubDeleteSeed(result: const Err(DeterministicWalletRollbackFailure()));
      final prepared = PreparedDeterministicWallets(
        wallets: [created],
        childSeedFingerprint: '3f635a63',
        childSeedStoredDuringAttempt: true,
      );

      final result = await usecase.rollbackCreatedWallets(prepared);

      expect(_failureOf(result), isA<DeterministicWalletRollbackFailure>());
    });
  });
}

PreparedDeterministicWallet _prepared(
  DeterministicWalletSpec spec, {
  required bool created,
}) {
  return PreparedDeterministicWallet(
    specId: spec.id,
    walletId: '${spec.id}-wallet-id',
    network: spec.network,
    scriptType: spec.scriptType,
    label: spec.label,
    externalPublicDescriptor: '${spec.id}-external',
    internalPublicDescriptor: '${spec.id}-internal',
    created: created,
  );
}

T _valueOf<T>(Result<T, DeterministicWalletFailure> result) {
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => fail('Expected Ok, got ${failure.runtimeType}'),
  };
}

DeterministicWalletFailure _failureOf<T>(
  Result<T, DeterministicWalletFailure> result,
) {
  return switch (result) {
    Ok() => fail('Expected Err, got Ok'),
    Err(:final failure) => failure,
  };
}
