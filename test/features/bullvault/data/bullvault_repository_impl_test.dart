import 'dart:convert';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_repository_impl.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_metadata_datasource.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_record_mapper.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_policy.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_recovery_package.dart';
import 'package:flutter_test/flutter_test.dart';

import '../bullvault_test_fixture.dart';

final class _MemoryStorage implements KeyValueStorageDatasource<String> {
  final Map<String, String> _values = {};
  String? failNextSaveForKey;

  @override
  Future<void> deleteAll() async => _values.clear();

  @override
  Future<void> deleteValue(String key) async => _values.remove(key);

  @override
  Future<Map<String, String>> getAll() async => Map.of(_values);

  @override
  Future<String?> getValue(String key) async => _values[key];

  @override
  Future<bool> hasValue(String key) async => _values.containsKey(key);

  @override
  Future<void> saveValue({required String key, required String value}) async {
    if (failNextSaveForKey == key) {
      failNextSaveForKey = null;
      throw Exception('storage unavailable');
    }
    _values[key] = value;
  }
}

void main() {
  test(
    'persists lineage and generation metadata with the wallet record',
    () async {
      final storage = _MemoryStorage();
      final repository = _repository(storage);

      final result = await repository.save(
        BullVaultRecord(
          walletId: 'wallet-id',
          lineageId: 'lineage-id',
          vaultGeneration: 1,
          mobileAccount: 0,
          birthHeight: 3_000_000,
          recoveryPackage: testBullVaultRecoveryPackage(
            previousVaultId: 'previous-wallet-id',
            lineageId: 'lineage-id',
            generation: 1,
          ),
          previousVaultId: 'previous-wallet-id',
          hardwareSetupDeferred: true,
          completedHardwareSignerIds: const {'cold', 'inheritance'},
          recoveryPackageConfirmed: true,
          mobileBackupDeferred: true,
          createdAt: DateTime.utc(2027, 1, 15),
        ),
      );
      final stored =
          jsonDecode((await storage.getValue('bullvault_record_wallet-id'))!)
              as Map<String, dynamic>;

      expect(switch (result) {
        Ok() => true,
        Err() => false,
      }, isTrue);
      expect(stored['lineageId'], 'lineage-id');
      expect(stored['vaultGeneration'], 1);
      expect(stored['completedHardwareSignerIds'], ['cold', 'inheritance']);
      expect(stored['recoveryPackageConfirmed'], isTrue);
      expect(stored['hardwareSetupDeferred'], isTrue);
      expect(stored['mobileBackupDeferred'], isTrue);
      final loaded = await repository.getByWalletId('wallet-id');
      final record = (loaded as Ok<BullVaultRecord?, BullVaultFailure>).value!;
      expect(record.hardwareSetupDeferred, isTrue);
      expect(record.mobileBackupDeferred, isTrue);
    },
  );

  test('round trips an unknown birth height', () async {
    final storage = _MemoryStorage();
    final repository = _repository(storage);
    final package = testBullVaultRecoveryPackage();
    final record = BullVaultRecord(
      walletId: 'wallet-id',
      lineageId: package.policy.lineageId,
      vaultGeneration: 0,
      mobileAccount: 0,
      birthHeight: null,
      recoveryPackage: package,
      createdAt: DateTime.utc(2027, 1, 15),
    );

    expect(await repository.save(record), isA<Ok<void, BullVaultFailure>>());
    final loaded = await repository.getByWalletId(record.walletId);

    expect(loaded, isA<Ok<BullVaultRecord?, BullVaultFailure>>());
    expect(
      (loaded as Ok<BullVaultRecord?, BullVaultFailure>).value?.birthHeight,
      isNull,
    );
  });

  test('persists and releases generation reservations', () async {
    final storage = _MemoryStorage();
    final current = BullVaultRecord(
      walletId: 'wallet-0',
      lineageId: 'lineage-id',
      vaultGeneration: 0,
      mobileAccount: 0,
      birthHeight: 3_000_000,
      recoveryPackage: testBullVaultRecoveryPackage(lineageId: 'lineage-id'),
      createdAt: DateTime.utc(2027, 1, 15),
    );
    final repository = _repository(storage);

    final first = await repository.reserveNextGeneration(current);
    final restored = _repository(storage);
    final reservedAfterRestart = await restored.reserveNextGeneration(current);
    await restored.releaseGeneration(
      lineageId: current.lineageId,
      generation: 2,
    );
    await restored.releaseGeneration(
      lineageId: current.lineageId,
      generation: 1,
    );
    final releasedRetry = await restored.reserveNextGeneration(current);
    final replacement = testBullVaultCreateResult(
      walletId: 'wallet-1',
      previousVaultId: current.walletId,
      lineageId: current.lineageId,
      generation: 1,
      status: BullVaultLifecycleStatus.pending,
    ).record;
    await repository.save(current);
    await repository.save(replacement);
    await restored.releaseGeneration(
      lineageId: current.lineageId,
      generation: 1,
    );
    final afterSave = await restored.reserveNextGeneration(current);

    expect((first as Ok<int, BullVaultFailure>).value, 1);
    expect((reservedAfterRestart as Ok<int, BullVaultFailure>).value, 2);
    expect((releasedRetry as Ok<int, BullVaultFailure>).value, 1);
    expect((afterSave as Ok<int, BullVaultFailure>).value, 2);
  });

  test('rejects a duplicate generation in the same lineage', () async {
    final storage = _MemoryStorage();
    final repository = _repository(storage);
    final first = testBullVaultCreateResult(
      walletId: 'wallet-1',
      previousVaultId: 'wallet-0',
      lineageId: 'lineage-id',
      generation: 1,
    ).record;
    final duplicate = BullVaultRecord(
      walletId: 'wallet-duplicate',
      lineageId: first.lineageId,
      vaultGeneration: first.vaultGeneration,
      mobileAccount: first.mobileAccount,
      birthHeight: first.birthHeight,
      recoveryPackage: first.recoveryPackage,
      previousVaultId: first.previousVaultId,
      status: first.status,
      createdAt: first.createdAt,
    );

    expect(await repository.save(first), isA<Ok<void, BullVaultFailure>>());
    expect(
      await repository.save(duplicate),
      isA<Err<void, BullVaultFailure>>(),
    );
    expect(
      (await repository.getByWalletId(first.walletId)
              as Ok<BullVaultRecord?, BullVaultFailure>)
          .value,
      isNotNull,
    );
    expect(
      (await repository.getByWalletId(duplicate.walletId)
              as Ok<BullVaultRecord?, BullVaultFailure>)
          .value,
      isNull,
    );
  });

  test('allows only one active wallet in a lineage', () async {
    final storage = _MemoryStorage();
    final repository = _repository(storage);
    final first = testBullVaultCreateResult(
      walletId: 'wallet-0',
      lineageId: 'lineage-id',
      status: BullVaultLifecycleStatus.active,
    ).record;
    final second = testBullVaultCreateResult(
      walletId: 'wallet-1',
      previousVaultId: first.walletId,
      lineageId: first.lineageId,
      generation: 1,
      status: BullVaultLifecycleStatus.active,
    ).record;

    final results = await Future.wait([
      repository.save(first),
      repository.save(second),
    ]);
    final lineage = await repository.getLineage(first.lineageId);

    expect(results.whereType<Ok<void, BullVaultFailure>>(), hasLength(1));
    expect(results.whereType<Err<void, BullVaultFailure>>(), hasLength(1));
    expect(
      (lineage as Ok<List<BullVaultRecord>, BullVaultFailure>).value.where(
        (record) => record.status == BullVaultLifecycleStatus.active,
      ),
      hasLength(1),
    );
  });

  test(
    'cancels a pending replacement without reusing its generation',
    () async {
      final storage = _MemoryStorage();
      final repository = _repository(storage);
      final previous = testBullVaultCreateResult(
        walletId: 'wallet-0',
        lineageId: 'lineage-id',
        status: BullVaultLifecycleStatus.active,
      ).record;
      final generation = switch (await repository.reserveNextGeneration(
        previous,
      )) {
        Ok(:final value) => value,
        Err(:final failure) => throw TestFailure('$failure'),
      };
      final replacement = testBullVaultCreateResult(
        walletId: 'wallet-1',
        previousVaultId: previous.walletId,
        lineageId: previous.lineageId,
        generation: generation,
        status: BullVaultLifecycleStatus.pending,
      ).record;
      await repository.save(previous);
      await repository.save(
        replacement.copyWith(status: BullVaultLifecycleStatus.activating),
      );

      final refused = await repository.cancelRenewal(
        previousWalletId: previous.walletId,
        replacementWalletId: replacement.walletId,
      );
      await repository.save(replacement);

      final cancelled = await repository.cancelRenewal(
        previousWalletId: previous.walletId,
        replacementWalletId: replacement.walletId,
      );
      final staleSave = await repository.save(replacement);
      final next = await repository.reserveNextGeneration(previous);
      final storedPrevious = await repository.getByWalletId(previous.walletId);
      final storedReplacement = await repository.getByWalletId(
        replacement.walletId,
      );

      expect(refused, isA<Err<void, BullVaultFailure>>());
      expect(cancelled, isA<Ok<void, BullVaultFailure>>());
      expect(staleSave, isA<Err<void, BullVaultFailure>>());
      expect((next as Ok<int, BullVaultFailure>).value, generation + 1);
      expect(
        (storedPrevious as Ok<BullVaultRecord?, BullVaultFailure>)
            .value
            ?.status,
        BullVaultLifecycleStatus.active,
      );
      expect(
        (storedReplacement as Ok<BullVaultRecord?, BullVaultFailure>)
            .value
            ?.status,
        BullVaultLifecycleStatus.cancelled,
      );
    },
  );

  test('rejects stale lifecycle transitions', () async {
    final storage = _MemoryStorage();
    final repository = _repository(storage);
    final pending = testBullVaultCreateResult(
      walletId: 'wallet-id',
      status: BullVaultLifecycleStatus.pending,
    ).record;
    final setupUpdated = pending.copyWith(recoveryPackageConfirmed: true);
    final activating = setupUpdated.copyWith(
      status: BullVaultLifecycleStatus.activating,
    );
    final active = activating.copyWith(status: BullVaultLifecycleStatus.active);
    final migrating = active.copyWith(
      successorWalletId: 'successor-id',
      status: BullVaultLifecycleStatus.migrating,
    );

    expect(await repository.save(pending), isA<Ok<void, BullVaultFailure>>());
    expect(
      await repository.save(setupUpdated),
      isA<Ok<void, BullVaultFailure>>(),
    );
    final storedSetup = await repository.getByWalletId(pending.walletId);
    expect(
      (storedSetup as Ok<BullVaultRecord?, BullVaultFailure>)
          .value
          ?.recoveryPackageConfirmed,
      isTrue,
    );
    expect(await repository.save(active), isA<Err<void, BullVaultFailure>>());
    expect(
      await repository.save(activating),
      isA<Ok<void, BullVaultFailure>>(),
    );
    expect(await repository.save(active), isA<Ok<void, BullVaultFailure>>());
    expect(await repository.save(pending), isA<Err<void, BullVaultFailure>>());
    expect(await repository.save(migrating), isA<Ok<void, BullVaultFailure>>());
    expect(await repository.save(active), isA<Err<void, BullVaultFailure>>());

    final stored = await repository.getByWalletId(pending.walletId);
    expect(
      (stored as Ok<BullVaultRecord?, BullVaultFailure>).value?.status,
      BullVaultLifecycleStatus.migrating,
    );
  });

  test('advances from a restored newer generation', () async {
    final storage = _MemoryStorage();
    final current = BullVaultRecord(
      walletId: 'wallet-3',
      lineageId: 'lineage-id',
      vaultGeneration: 3,
      mobileAccount: 0,
      birthHeight: 3_300_000,
      recoveryPackage: testBullVaultRecoveryPackage(
        previousVaultId: 'wallet-2',
        lineageId: 'lineage-id',
        generation: 3,
      ),
      previousVaultId: 'wallet-2',
      createdAt: DateTime.utc(2030),
    );
    final repository = _repository(storage);

    final generation = await repository.reserveNextGeneration(current);

    expect((generation as Ok<int, BullVaultFailure>).value, 4);
  });

  test(
    'activates a configured replacement and marks its predecessor migrating',
    () async {
      final storage = _MemoryStorage();
      final repository = _repository(storage);
      final previous = BullVaultRecord(
        walletId: 'wallet-0',
        lineageId: 'lineage-id',
        vaultGeneration: 0,
        mobileAccount: 0,
        birthHeight: 3_000_000,
        recoveryPackage: testBullVaultRecoveryPackage(lineageId: 'lineage-id'),
        createdAt: DateTime.utc(2027, 1, 15),
      );
      final replacement = BullVaultRecord(
        walletId: 'wallet-1',
        lineageId: 'lineage-id',
        vaultGeneration: 1,
        mobileAccount: 0,
        birthHeight: 3_100_000,
        recoveryPackage: testBullVaultRecoveryPackage(
          previousVaultId: 'wallet-0',
          lineageId: 'lineage-id',
          generation: 1,
        ),
        previousVaultId: previous.walletId,
        status: BullVaultLifecycleStatus.activating,
        hardwareSetupComplete: true,
        recoveryPackageConfirmed: true,
        createdAt: DateTime.utc(2028, 1, 15),
      );
      await repository.save(previous);
      await repository.save(replacement);

      final result = await repository.activateRenewal(
        previous: previous,
        replacement: replacement,
      );
      final loadedPrevious = await repository.getByWalletId(previous.walletId);
      final loadedReplacement = await repository.getByWalletId(
        replacement.walletId,
      );

      expect(result, isA<Ok<void, BullVaultFailure>>());
      expect(
        (loadedPrevious as Ok<BullVaultRecord?, BullVaultFailure>)
            .value!
            .status,
        BullVaultLifecycleStatus.migrating,
      );
      expect(loadedPrevious.value!.successorWalletId, replacement.walletId);
      expect(
        (loadedReplacement as Ok<BullVaultRecord?, BullVaultFailure>)
            .value!
            .status,
        BullVaultLifecycleStatus.active,
      );
      expect(
        await repository.activateRenewal(
          previous: previous,
          replacement: replacement,
        ),
        isA<Ok<void, BullVaultFailure>>(),
      );
    },
  );

  test('links restored renewal metadata to its active predecessor', () async {
    final storage = _MemoryStorage();
    final repository = _repository(storage);
    final previous = testBullVaultCreateResult(
      walletId: 'wallet-0',
      lineageId: 'lineage-id',
      status: BullVaultLifecycleStatus.active,
    ).record;
    final codec = testBullVaultRecoveryPackageCodec();
    final restoredPackage = codec.decode(
      codec.encode(
        testBullVaultRecoveryPackage(
          previousVaultId: previous.walletId,
          lineageId: previous.lineageId,
          generation: 1,
        ),
      ),
    );
    final restoredPolicy = restoredPackage.policy;
    final descriptorOnlyPackage = BullVaultRecoveryPackage(
      policy: BullVaultPolicy.restoreDescriptor(
        vaultGeneration: restoredPolicy.vaultGeneration,
        network: restoredPolicy.network,
        descriptor: restoredPolicy.descriptor,
        protection: restoredPolicy.protection,
        everydayKey: restoredPolicy.everydayKey,
        coldKey: restoredPolicy.coldKey,
        secondColdKey: restoredPolicy.secondColdKey,
        inheritanceKey: restoredPolicy.inheritanceKey,
        coldActivationTimestamp: restoredPolicy.coldActivationTimestamp,
        recoveryActivationTimestamp:
            restoredPolicy.recoveryActivationTimestamp!,
        inheritanceActivationTimestamp:
            restoredPolicy.inheritanceActivationTimestamp,
      ).withEverydayOwnership(SignerEntity.local),
    );
    final ownedRestoredPackage = BullVaultRecoveryPackage(
      previousVaultId: restoredPackage.previousVaultId,
      policy: restoredPackage.policy.withEverydayOwnership(SignerEntity.local),
    );
    final descriptorOnly = BullVaultRecord(
      walletId: 'wallet-1',
      lineageId: descriptorOnlyPackage.policy.lineageId,
      vaultGeneration: 1,
      mobileAccount: 0,
      birthHeight: null,
      recoveryPackage: descriptorOnlyPackage,
      status: BullVaultLifecycleStatus.active,
      recoveryPackageConfirmed: true,
      createdAt: DateTime.utc(2028, 1, 15),
    );
    final restored = BullVaultRecord(
      walletId: descriptorOnly.walletId,
      lineageId: restoredPackage.policy.lineageId,
      vaultGeneration: 1,
      mobileAccount: 0,
      birthHeight: ownedRestoredPackage.policy.birthHeight,
      recoveryPackage: ownedRestoredPackage,
      previousVaultId: previous.walletId,
      status: BullVaultLifecycleStatus.active,
      recoveryPackageConfirmed: true,
      createdAt: restoredPackage.policy.createdAt!,
    );
    expect(await repository.save(previous), isA<Ok<void, BullVaultFailure>>());
    expect(
      await repository.save(descriptorOnly),
      isA<Ok<void, BullVaultFailure>>(),
    );

    final result = await repository.linkRestoredRenewal(
      previous: previous,
      successor: restored,
    );
    final storedPrevious = await repository.getByWalletId(previous.walletId);
    final storedSuccessor = await repository.getByWalletId(restored.walletId);

    expect(result, isA<Ok<void, BullVaultFailure>>());
    expect(
      (storedPrevious as Ok<BullVaultRecord?, BullVaultFailure>).value!.status,
      BullVaultLifecycleStatus.migrating,
    );
    expect(storedPrevious.value!.successorWalletId, restored.walletId);
    expect(
      (storedSuccessor as Ok<BullVaultRecord?, BullVaultFailure>)
          .value!
          .recoveryPackageConfirmed,
      isTrue,
    );
    expect(storedSuccessor.value!.lineageId, previous.lineageId);
    expect(storedSuccessor.value!.previousVaultId, previous.walletId);
  });

  test(
    'restores the predecessor when restored renewal linking fails',
    () async {
      final storage = _MemoryStorage();
      final repository = _repository(storage);
      final previous = testBullVaultCreateResult(
        walletId: 'wallet-0',
        lineageId: 'lineage-id',
        status: BullVaultLifecycleStatus.active,
      ).record;
      final package = testBullVaultRecoveryPackage(
        previousVaultId: previous.walletId,
        lineageId: previous.lineageId,
        generation: 1,
      );
      final descriptorOnly = _descriptorOnlyRecord(package);
      final restored = BullVaultRecord(
        walletId: descriptorOnly.walletId,
        lineageId: package.policy.lineageId,
        vaultGeneration: 1,
        mobileAccount: 0,
        birthHeight: package.policy.birthHeight,
        recoveryPackage: package,
        previousVaultId: previous.walletId,
        status: BullVaultLifecycleStatus.active,
        recoveryPackageConfirmed: true,
        createdAt: DateTime.utc(2028),
      );
      await repository.save(previous);
      await repository.save(descriptorOnly);
      storage.failNextSaveForKey = 'bullvault_record_${previous.walletId}';

      final result = await repository.linkRestoredRenewal(
        previous: previous,
        successor: restored,
      );
      final storedPrevious = await repository.getByWalletId(previous.walletId);
      final storedSuccessor = await repository.getByWalletId(restored.walletId);

      expect(result, isA<Err<void, BullVaultFailure>>());
      expect(
        (storedPrevious as Ok<BullVaultRecord?, BullVaultFailure>)
            .value!
            .status,
        BullVaultLifecycleStatus.active,
      );
      expect(storedPrevious.value!.successorWalletId, isNull);
      expect(
        (storedSuccessor as Ok<BullVaultRecord?, BullVaultFailure>)
            .value!
            .recoveryPackageConfirmed,
        isFalse,
      );
    },
  );

  test('repairs an interrupted restored renewal link', () async {
    final storage = _MemoryStorage();
    final repository = _repository(storage);
    final codec = testBullVaultRecoveryPackageCodec();
    final mapper = BullVaultRecordMapper(codec);
    final datasource = BullVaultMetadataDatasource(storage);
    final previous = testBullVaultCreateResult(
      walletId: 'wallet-0',
      lineageId: 'lineage-id',
      status: BullVaultLifecycleStatus.active,
    ).record;
    final package = testBullVaultRecoveryPackage(
      previousVaultId: previous.walletId,
      lineageId: previous.lineageId,
      generation: 1,
    );
    final descriptorOnly = _descriptorOnlyRecord(package);
    final restored = BullVaultRecord(
      walletId: descriptorOnly.walletId,
      lineageId: package.policy.lineageId,
      vaultGeneration: package.policy.vaultGeneration,
      mobileAccount: descriptorOnly.mobileAccount,
      birthHeight: package.policy.birthHeight,
      recoveryPackage: package,
      previousVaultId: previous.walletId,
      status: BullVaultLifecycleStatus.active,
      recoveryPackageConfirmed: true,
      createdAt: DateTime.utc(2028),
    );
    await repository.save(previous);
    await repository.save(descriptorOnly);
    await datasource.save(mapper.toModel(restored));

    final repairedPrevious = await repository.getByWalletId(previous.walletId);
    final repairedSuccessor = await repository.getByWalletId(restored.walletId);

    expect(
      (repairedPrevious as Ok<BullVaultRecord?, BullVaultFailure>)
          .value!
          .status,
      BullVaultLifecycleStatus.migrating,
    );
    expect(repairedPrevious.value!.successorWalletId, restored.walletId);
    expect(
      (repairedSuccessor as Ok<BullVaultRecord?, BullVaultFailure>)
          .value!
          .recoveryPackageConfirmed,
      isTrue,
    );
    expect(repairedSuccessor.value!.lineageId, previous.lineageId);
  });

  test(
    'rejects a restored link that duplicates a lineage generation',
    () async {
      final storage = _MemoryStorage();
      final repository = _repository(storage);
      final previous = testBullVaultCreateResult(
        walletId: 'wallet-0',
        lineageId: 'lineage-id',
        status: BullVaultLifecycleStatus.active,
      ).record;
      final package = testBullVaultRecoveryPackage(
        previousVaultId: previous.walletId,
        lineageId: previous.lineageId,
        generation: 1,
      );
      final cancelled = BullVaultRecord(
        walletId: 'cancelled-wallet',
        lineageId: package.policy.lineageId,
        vaultGeneration: 1,
        mobileAccount: 0,
        birthHeight: package.policy.birthHeight,
        recoveryPackage: package,
        previousVaultId: previous.walletId,
        status: BullVaultLifecycleStatus.cancelled,
        createdAt: DateTime.utc(2028),
      );
      final descriptorOnly = _descriptorOnlyRecord(package);
      final restored = BullVaultRecord(
        walletId: descriptorOnly.walletId,
        lineageId: package.policy.lineageId,
        vaultGeneration: 1,
        mobileAccount: 0,
        birthHeight: package.policy.birthHeight,
        recoveryPackage: package,
        previousVaultId: previous.walletId,
        status: BullVaultLifecycleStatus.active,
        recoveryPackageConfirmed: true,
        createdAt: DateTime.utc(2028),
      );
      await repository.save(previous);
      await repository.save(cancelled);
      await repository.save(descriptorOnly);

      final result = await repository.linkRestoredRenewal(
        previous: previous,
        successor: restored,
      );

      expect(result, isA<Err<void, BullVaultFailure>>());
      expect(
        (await repository.getByWalletId(previous.walletId)
                as Ok<BullVaultRecord?, BullVaultFailure>)
            .value!
            .status,
        BullVaultLifecycleStatus.active,
      );
    },
  );

  test('restores the predecessor when replacement activation fails', () async {
    final storage = _MemoryStorage();
    final repository = _repository(storage);
    final previous = BullVaultRecord(
      walletId: 'wallet-0',
      lineageId: 'lineage-id',
      vaultGeneration: 0,
      mobileAccount: 0,
      birthHeight: 3_000_000,
      recoveryPackage: testBullVaultRecoveryPackage(lineageId: 'lineage-id'),
      createdAt: DateTime.utc(2027, 1, 15),
    );
    final replacement = BullVaultRecord(
      walletId: 'wallet-1',
      lineageId: 'lineage-id',
      vaultGeneration: 1,
      mobileAccount: 0,
      birthHeight: 3_100_000,
      recoveryPackage: testBullVaultRecoveryPackage(
        previousVaultId: 'wallet-0',
        lineageId: 'lineage-id',
        generation: 1,
      ),
      previousVaultId: previous.walletId,
      status: BullVaultLifecycleStatus.activating,
      hardwareSetupComplete: true,
      recoveryPackageConfirmed: true,
      createdAt: DateTime.utc(2028, 1, 15),
    );
    await repository.save(previous);
    await repository.save(replacement);
    storage.failNextSaveForKey = 'bullvault_record_wallet-1';

    final result = await repository.activateRenewal(
      previous: previous,
      replacement: replacement,
    );
    final loadedPrevious = await repository.getByWalletId(previous.walletId);
    final loadedReplacement = await repository.getByWalletId(
      replacement.walletId,
    );

    expect(result, isA<Err<void, BullVaultFailure>>());
    expect(
      (loadedPrevious as Ok<BullVaultRecord?, BullVaultFailure>).value!.status,
      BullVaultLifecycleStatus.active,
    );
    expect(loadedPrevious.value!.successorWalletId, isNull);
    expect(
      (loadedReplacement as Ok<BullVaultRecord?, BullVaultFailure>)
          .value!
          .status,
      BullVaultLifecycleStatus.activating,
    );
  });
}

BullVaultRepositoryImpl _repository(_MemoryStorage storage) {
  final codec = testBullVaultRecoveryPackageCodec();
  return BullVaultRepositoryImpl(
    BullVaultMetadataDatasource(storage),
    BullVaultRecordMapper(codec),
    codec,
  );
}

BullVaultRecord _descriptorOnlyRecord(BullVaultRecoveryPackage package) {
  final policy = package.policy;
  final descriptorPackage = BullVaultRecoveryPackage(
    policy: BullVaultPolicy.restoreDescriptor(
      vaultGeneration: policy.vaultGeneration,
      network: policy.network,
      descriptor: policy.descriptor,
      protection: policy.protection,
      everydayKey: policy.everydayKey,
      coldKey: policy.coldKey,
      secondColdKey: policy.secondColdKey,
      inheritanceKey: policy.inheritanceKey,
      coldActivationTimestamp: policy.coldActivationTimestamp,
      recoveryActivationTimestamp: policy.recoveryActivationTimestamp!,
      inheritanceActivationTimestamp: policy.inheritanceActivationTimestamp,
    ),
  );
  return BullVaultRecord(
    walletId: 'descriptor-wallet',
    lineageId: descriptorPackage.policy.lineageId,
    vaultGeneration: policy.vaultGeneration,
    mobileAccount: 0,
    birthHeight: null,
    recoveryPackage: descriptorPackage,
    status: BullVaultLifecycleStatus.active,
    createdAt: DateTime.utc(2028),
  );
}
