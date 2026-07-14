import 'dart:typed_data';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/seed_failure.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/deterministic_wallets/data/deterministic_wallet_repository_impl.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/deterministic_wallet_failure.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/deterministic_wallet_seed_material.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/deterministic_wallets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockSeedRepository extends Mock implements SeedRepository {}

const _spec = DeterministicWalletSpec(
  id: 'product-bitcoin',
  network: Network.bitcoinMainnet,
  scriptType: ScriptType.bip84,
  label: 'Product Bitcoin',
  isDefault: false,
  sync: false,
);

void main() {
  final seedMaterial = DeterministicWalletSeedMaterial(
    mnemonicWords: List.filled(11, 'zoo') + ['wrong'],
    seedBytes: Uint8List.fromList(List.generate(64, (index) => index)),
    masterFingerprint: '3f635a63',
  );
  final metadata = _metadata();

  late _MockWalletRepository walletRepository;
  late _MockSeedRepository seedRepository;
  late DeterministicWalletRepositoryImpl repository;
  late Seed? derivedSeed;

  setUpAll(() {
    registerFallbackValue(
      Seed.bytes(
        bytes: Uint8List.fromList(const [0]),
        masterFingerprint: 'fallback',
      ),
    );
  });

  setUp(() {
    walletRepository = _MockWalletRepository();
    seedRepository = _MockSeedRepository();
    derivedSeed = null;
    repository = DeterministicWalletRepositoryImpl(
      walletRepository: walletRepository,
      seedRepository: seedRepository,
      deriveWalletMetadata:
          ({
            required seed,
            required network,
            required scriptType,
            label,
            required isDefault,
          }) async {
            derivedSeed = seed;
            expect(network, _spec.network);
            expect(scriptType, _spec.scriptType);
            expect(label, _spec.label);
            expect(isDefault, _spec.isDefault);
            return metadata;
          },
    );
  });

  group('getMatchingWallet', () {
    test('returns null when the deterministic wallet does not exist', () async {
      when(
        () => walletRepository.getWallet(metadata.id),
      ).thenAnswer((_) async => null);

      final result = await repository.getMatchingWallet(
        seedMaterial: seedMaterial,
        spec: _spec,
      );

      expect(_valueOf(result), isNull);
      expect(derivedSeed, isA<MnemonicSeed>());
      expect(derivedSeed!.bytes, seedMaterial.seedBytes);
      expect(derivedSeed!.masterFingerprint, seedMaterial.masterFingerprint);
    });

    test('maps a matching core wallet to a reused public result', () async {
      final wallet = _wallet();
      when(
        () => walletRepository.getWallet(metadata.id),
      ).thenAnswer((_) async => wallet);

      final result = await repository.getMatchingWallet(
        seedMaterial: seedMaterial,
        spec: _spec,
      );
      final prepared = _valueOf(result)!;

      expect(prepared.specId, _spec.id);
      expect(prepared.walletId, wallet.id);
      expect(prepared.network, wallet.network);
      expect(prepared.scriptType, wallet.scriptType);
      expect(prepared.label, wallet.label);
      expect(prepared.externalPublicDescriptor, 'external-descriptor');
      expect(prepared.internalPublicDescriptor, 'internal-descriptor');
      expect(prepared.created, isFalse);
    });

    test('returns typed mismatch when descriptors do not match', () async {
      when(() => walletRepository.getWallet(metadata.id)).thenAnswer(
        (_) async => _wallet(externalDescriptor: 'unexpected-descriptor'),
      );

      final result = await repository.getMatchingWallet(
        seedMaterial: seedMaterial,
        spec: _spec,
      );

      expect(_failureOf(result), isA<DeterministicWalletMismatchFailure>());
    });

    test('maps metadata or lookup exceptions to operation failure', () async {
      repository = DeterministicWalletRepositoryImpl(
        walletRepository: walletRepository,
        seedRepository: seedRepository,
        deriveWalletMetadata:
            ({
              required seed,
              required network,
              required scriptType,
              label,
              required isDefault,
            }) async => throw Exception('metadata failed'),
      );

      final result = await repository.getMatchingWallet(
        seedMaterial: seedMaterial,
        spec: _spec,
      );

      expect(_failureOf(result), isA<DeterministicWalletOperationFailure>());
    });
  });

  group('createWallet', () {
    test('maps a created core wallet to a created public result', () async {
      final wallet = _wallet();
      when(
        () => walletRepository.createWallet(
          seed: any(named: 'seed'),
          network: _spec.network,
          scriptType: _spec.scriptType,
          label: _spec.label,
          isDefault: _spec.isDefault,
          sync: _spec.sync,
        ),
      ).thenAnswer((_) async => wallet);

      final result = await repository.createWallet(
        seedMaterial: seedMaterial,
        spec: _spec,
      );
      final prepared = _valueOf(result);

      expect(prepared.walletId, wallet.id);
      expect(prepared.created, isTrue);
      final captured =
          verify(
                () => walletRepository.createWallet(
                  seed: captureAny(named: 'seed'),
                  network: _spec.network,
                  scriptType: _spec.scriptType,
                  label: _spec.label,
                  isDefault: _spec.isDefault,
                  sync: _spec.sync,
                ),
              ).captured.single
              as MnemonicSeed;
      expect(captured.mnemonicWords, seedMaterial.mnemonicWords);
      expect(captured.bytes, seedMaterial.seedBytes);
    });

    test('maps core creation exceptions to operation failure', () async {
      when(
        () => walletRepository.createWallet(
          seed: any(named: 'seed'),
          network: _spec.network,
          scriptType: _spec.scriptType,
          label: _spec.label,
          isDefault: _spec.isDefault,
          sync: _spec.sync,
        ),
      ).thenThrow(Exception('create failed'));

      final result = await repository.createWallet(
        seedMaterial: seedMaterial,
        spec: _spec,
      );

      expect(_failureOf(result), isA<DeterministicWalletOperationFailure>());
    });
  });

  group('child seed mapping', () {
    test('maps existence and storage success', () async {
      when(
        () => seedRepository.exists(seedMaterial.masterFingerprint),
      ).thenAnswer((_) async => true);
      when(
        () => seedRepository.createFromMnemonic(
          mnemonicWords: seedMaterial.mnemonicWords,
        ),
      ).thenAnswer((_) async => _mnemonicSeed(seedMaterial));

      final exists = await repository.childSeedExists(
        seedMaterial.masterFingerprint,
      );
      final stored = await repository.storeChildSeed(seedMaterial);

      expect(_valueOf(exists), isTrue);
      expect(stored, isA<Ok<void, DeterministicWalletFailure>>());
      verify(
        () => seedRepository.createFromMnemonic(
          mnemonicWords: seedMaterial.mnemonicWords,
        ),
      ).called(1);
    });

    test('maps existence and storage exceptions to storage failure', () async {
      when(
        () => seedRepository.exists(seedMaterial.masterFingerprint),
      ).thenThrow(Exception('lookup failed'));
      when(
        () => seedRepository.createFromMnemonic(
          mnemonicWords: seedMaterial.mnemonicWords,
        ),
      ).thenThrow(Exception('store failed'));

      final exists = await repository.childSeedExists(
        seedMaterial.masterFingerprint,
      );
      final stored = await repository.storeChildSeed(seedMaterial);

      expect(_failureOf(exists), isA<DeterministicWalletStorageFailure>());
      expect(_failureOf(stored), isA<DeterministicWalletStorageFailure>());
    });
  });

  group('delete mapping', () {
    test('maps wallet and seed deletion success', () async {
      when(
        () => walletRepository.deleteWallet(walletId: 'wallet-id'),
      ).thenAnswer((_) async {});
      when(
        () => seedRepository.delete(seedMaterial.masterFingerprint),
      ).thenAnswer((_) async => const Ok(null));

      final wallet = await repository.deleteWallet('wallet-id');
      final seed = await repository.deleteChildSeed(
        seedMaterial.masterFingerprint,
      );

      expect(wallet, isA<Ok<void, DeterministicWalletFailure>>());
      expect(seed, isA<Ok<void, DeterministicWalletFailure>>());
    });

    test(
      'maps wallet exception and seed failure to rollback failure',
      () async {
        when(
          () => walletRepository.deleteWallet(walletId: 'wallet-id'),
        ).thenThrow(Exception('delete failed'));
        when(
          () => seedRepository.delete(seedMaterial.masterFingerprint),
        ).thenAnswer(
          (_) async => const Err(SeedDeleteFailure('delete failed')),
        );

        final wallet = await repository.deleteWallet('wallet-id');
        final seed = await repository.deleteChildSeed(
          seedMaterial.masterFingerprint,
        );

        expect(_failureOf(wallet), isA<DeterministicWalletRollbackFailure>());
        expect(_failureOf(seed), isA<DeterministicWalletRollbackFailure>());
      },
    );

    test('maps an unexpected seed-delete throw to rollback failure', () async {
      when(
        () => seedRepository.delete(seedMaterial.masterFingerprint),
      ).thenThrow(Exception('delete threw'));

      final result = await repository.deleteChildSeed(
        seedMaterial.masterFingerprint,
      );

      expect(_failureOf(result), isA<DeterministicWalletRollbackFailure>());
    });
  });
}

WalletMetadataModel _metadata() {
  return const WalletMetadataModel(
    id: 'wpkh([3f635a63/84h/0h/0h])',
    masterFingerprint: '3f635a63',
    xpubFingerprint: 'xpub-fingerprint',
    isEncryptedVaultTested: false,
    isPhysicalBackupTested: false,
    xpub: 'xpub',
    externalPublicDescriptor: 'external-descriptor',
    internalPublicDescriptor: 'internal-descriptor',
    signer: Signer.local,
    isDefault: false,
    label: 'Product Bitcoin',
  );
}

Wallet _wallet({String externalDescriptor = 'external-descriptor'}) {
  return Wallet(
    origin: 'wpkh([3f635a63/84h/0h/0h])',
    label: 'Product Bitcoin',
    network: Network.bitcoinMainnet,
    isDefault: false,
    masterFingerprint: '3f635a63',
    xpubFingerprint: 'xpub-fingerprint',
    scriptType: ScriptType.bip84,
    xpub: 'xpub',
    externalPublicDescriptor: externalDescriptor,
    internalPublicDescriptor: 'internal-descriptor',
    signer: SignerEntity.local,
    signerDevice: null,
    balanceSat: BigInt.zero,
  );
}

MnemonicSeed _mnemonicSeed(DeterministicWalletSeedMaterial material) {
  return Seed.mnemonic(
        mnemonicWords: material.mnemonicWords,
        bytes: material.seedBytes,
        masterFingerprint: material.masterFingerprint,
      )
      as MnemonicSeed;
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
