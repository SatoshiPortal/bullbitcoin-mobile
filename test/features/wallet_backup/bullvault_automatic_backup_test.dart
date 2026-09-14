// These scenarios run several real encrypted publications; full-suite CPU
// contention can exceed the default 30-second unit-test deadline.
@Timeout(Duration(minutes: 2))
library;

import 'dart:async';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bullvault/data/bip138_codec.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_metadata_datasource.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_record_mapper.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_repository_impl.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/watch_bullvault_backup_changes_usecase.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/wallet_backup/data/bullvault_backup.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_encryption.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_vault_entry.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../bullvault/bullvault_test_fixture.dart';
import 'support/wallet_backup_behavior_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SqliteDatabase database;
  late BullVaultRepositoryImpl repository;
  late WalletBackupBehaviorHarness device;

  Future<WalletBackupBehaviorHarness> create({
    FakeWalletBackupRemote? remote,
  }) async {
    final codec = testBullVaultRecoveryPackageCodec();
    repository = BullVaultRepositoryImpl(
      BullVaultMetadataDatasource(database),
      BullVaultRecordMapper(codec),
      codec,
      Bip138Codec(),
    );
    return WalletBackupBehaviorHarness.create(
      database: database,
      remote: remote,
      recordedChanges: WatchBullVaultBackupChangesUsecase(repository).execute(),
      vaultSection: BullVaultBackupImpl(
        listRecords: repository.getAll,
        encodePackage: repository.encodeRecoveryPackage,
        walletLabel: (_) async => null,
        currentNetwork: () async => Network.bitcoinMainnet,
        walletExists: (_) async => false,
        restore: ({required source, required label, required status}) async =>
            const Err(BullVaultInvalidRecoveryFailure()),
      ),
      inspectVault: (source) {
        final policy = codec.decode(source).policy;
        return WalletBackupVaultPackageFacts(
          network: policy.network,
          lineageId: policy.lineageId,
          vaultGeneration: policy.vaultGeneration,
          descriptor: policy.descriptor,
          birthHeight: policy.birthHeight,
        );
      },
    );
  }

  List<WalletBackupVaultEntry> remoteVaults() =>
      switch (device.encryption.decrypt(
        ciphertext: WalletBackupCiphertext(device.remote.storedCiphertext!),
        key: device.encryptionKey,
        expectedParentFingerprint: device.parentFingerprint,
      )) {
        Ok(:final value) => value.vaults,
        Err(:final failure) => throw StateError(
          'Failed to decode test backup: ${failure.runtimeType}',
        ),
      };

  Future<void> published(Map<String, String> expected) => settleUntil(() async {
    final actual = {
      for (final entry in remoteVaults()) entry.walletRef: entry.status,
    };
    return !(await device.readState()).dirty &&
        actual.length == expected.length &&
        expected.entries.every((entry) => actual[entry.key] == entry.value);
  }, description: 'automatic vault publication $expected');

  setUp(() async {
    database = SqliteDatabase(NativeDatabase.memory());
    device = await create();
    for (final id in ['first', 'next']) {
      await database
          .into(database.walletMetadatas)
          .insert(
            WalletMetadatasCompanion.insert(
              id: id,
              network: Network.bitcoinMainnet,
              publicDescriptor: '',
              isEncryptedVaultTested: false,
              isPhysicalBackupTested: false,
              isDefault: false,
            ),
          );
    }
    expect(await device.facade.setEnabled(true), isA<Ok>());
    device.startCoordinator();
    await published({});
  });
  tearDown(() => device.dispose());

  test(
    'create, activate, renew and delete publish without unrelated edits',
    () async {
      final first = testBullVaultCreateResult(walletId: 'first').record
          .copyWith(
            hardwareSetupComplete: true,
            recoveryPackageConfirmed: true,
          );
      expect(await repository.save(first), isA<Ok>());
      await published({'first': 'pending'});
      final afterCreate = (await device.readState()).localRevision;
      expect(await repository.activateInitial(first), isA<Ok>());
      await published({'first': 'active'});
      expect(
        (await device.readState()).localRevision,
        afterCreate + 1,
        reason: 'recordedChanges must not increment the revision again',
      );
      final next =
          testBullVaultCreateResult(
            walletId: 'next',
            lineageId: first.lineageId,
            previousVaultId: 'first',
            generation: 1,
          ).record.copyWith(
            hardwareSetupComplete: true,
            recoveryPackageConfirmed: true,
          );
      expect(await repository.save(next), isA<Ok>());
      await published({'first': 'active', 'next': 'pending'});
      expect(
        await repository.activateRenewal(previous: first, replacement: next),
        isA<Ok>(),
      );
      await published({'first': 'migrating', 'next': 'active'});
      expect(remoteVaults().map((entry) => entry.vaultGeneration), [0, 1]);
      final storedNext =
          (await repository.getByWalletId('next')
                  as Ok<BullVaultRecord?, BullVaultFailure>)
              .value!;
      expect(
        remoteVaults().last.recoveryPackage,
        repository.encodeRecoveryPackage(storedNext.recoveryPackage),
      );
      expect(await repository.delete('first'), isA<Ok>());
      await published({'next': 'active'});
    },
  );

  test(
    'restart publishes a vault committed while no trigger was listening',
    () async {
      final remote = device.remote;
      await device.dispose(closeDatabase: false);
      expect(
        await repository.save(
          testBullVaultCreateResult(walletId: 'first').record,
        ),
        isA<Ok>(),
      );
      expect(remote.storedCiphertext, isNotNull);
      device = await create(remote: remote);
      expect((await device.readState()).dirty, isTrue);
      device.startCoordinator();
      await published({'first': 'pending'});
    },
  );

  test(
    'cancelled renewal is published and setup-only edits stay clean',
    () async {
      final first = testBullVaultCreateResult(
        walletId: 'first',
        status: BullVaultLifecycleStatus.active,
      ).record;
      final next = testBullVaultCreateResult(
        walletId: 'next',
        lineageId: first.lineageId,
        previousVaultId: 'first',
        generation: 1,
      ).record;
      expect(await repository.save(first), isA<Ok>());
      expect(await repository.save(next), isA<Ok>());
      await published({'first': 'active', 'next': 'pending'});
      final stores = device.remote.storeCount;
      final revision = (await device.readState()).localRevision;
      expect(
        await repository.save(next.copyWith(recoveryPackageConfirmed: true)),
        isA<Ok>(),
      );
      await pumpEventQueue();
      expect(device.remote.storeCount, stores);
      expect((await device.readState()).localRevision, revision);
      expect(
        await repository.cancelRenewal(
          previousWalletId: 'first',
          replacementWalletId: 'next',
        ),
        isA<Ok>(),
      );
      await published({'first': 'active', 'next': 'cancelled'});
    },
  );

  test(
    'a vault changed during upload remains pending for a later publication',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      device.remote.beforeStore = () async {
        device.remote.beforeStore = null;
        entered.complete();
        await release.future;
      };
      final first = testBullVaultCreateResult(walletId: 'first').record
          .copyWith(
            hardwareSetupComplete: true,
            recoveryPackageConfirmed: true,
          );
      await repository.save(first);
      await entered.future;
      final before = device.remote.storeCount;
      expect(await repository.activateInitial(first), isA<Ok>());
      release.complete();
      await published({'first': 'active'});
      expect(device.remote.storeCount, before + 2);
    },
  );
}
