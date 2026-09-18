import 'package:drift/drift.dart' show Value;

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_metadata_datasource.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_record_mapper.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_repository_impl.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../bullvault_test_fixture.dart';

void main() {
  late SqliteDatabase database;
  late BullVaultMetadataDatasource owner;
  late BullVaultRepositoryImpl repository;
  setUp(() async {
    database = SqliteDatabase(NativeDatabase.memory());
    owner = BullVaultMetadataDatasource(database);
    final codec = testBullVaultRecoveryPackageCodec();
    repository = BullVaultRepositoryImpl(
      owner,
      BullVaultRecordMapper(codec),
      codec,
    );
    await database.select(database.bullVaultRecords).get();
  });
  tearDown(() => database.close());
  test(
    'backup inventory contains every lifecycle status and generation',
    () async {
      for (final (generation, status)
          in BullVaultLifecycleStatus.values.indexed) {
        final record = testBullVaultCreateResult(
          walletId: 'wallet-$generation',
          lineageId: 'family',
          generation: generation,
          previousVaultId: generation == 0 ? null : 'wallet-${generation - 1}',
          status: status,
        ).record;
        expect(await repository.save(record), isA<Ok>());
      }
      final result = await repository.getAll();
      final records =
          (result as Ok<List<BullVaultRecord>, BullVaultFailure>).value;
      expect(
        records.map((r) => r.status).toSet(),
        BullVaultLifecycleStatus.values.toSet(),
      );
      expect(records.map((r) => r.vaultGeneration), [0, 1, 2, 3]);
    },
  );
  test('owner invalidation covers saved and deleted packages', () async {
    var count = 0;
    final subscription = repository.changes.listen((_) => count++);
    addTearDown(subscription.cancel);
    final record = testBullVaultCreateResult().record;
    expect(await repository.save(record), isA<Ok>());
    await Future<void>.delayed(Duration.zero);
    expect(count, greaterThan(0));
    final before = count;
    expect(await repository.delete(record.walletId), isA<Ok>());
    await Future<void>.delayed(Duration.zero);
    expect(count, greaterThan(before));
    expect((await repository.getAll() as Ok).value, isEmpty);
  });
  test(
    'an unreadable package cannot disappear from a complete inventory',
    () async {
      final record = testBullVaultCreateResult().record;
      expect(await repository.save(record), isA<Ok>());
      final stored = (await owner.load(record.walletId))!;
      await owner.save(stored.copyWith(recoveryPackage: '{}'));
      expect(await repository.getAll(), isA<Err>());
    },
  );
  Future<({BullVaultRecord previous, BullVaultRecord successor})>
  family() async {
    final previous = testBullVaultCreateResult(
      walletId: 'previous',
      lineageId: 'recovered-family',
      status: BullVaultLifecycleStatus.migrating,
    ).record;
    final successor = testBullVaultCreateResult(
      walletId: 'successor',
      lineageId: previous.lineageId,
      generation: 1,
      previousVaultId: previous.walletId,
      status: BullVaultLifecycleStatus.active,
    ).record;
    for (final record in [previous, successor]) {
      await database
          .into(database.walletMetadatas)
          .insert(
            WalletMetadatasCompanion.insert(
              id: record.walletId,
              network: record.recoveryPackage.policy.network,
              publicDescriptor: record.recoveryPackage.policy.descriptor,
              isDefault: false,
              isEncryptedVaultTested: false,
              isPhysicalBackupTested: false,
              isHidden: const Value(true),
            ),
          );
    }
    expect(await repository.save(previous), isA<Ok>());
    return (previous: previous, successor: successor);
  }

  test(
    'publishing the recovered successor reconnects its migrating predecessor',
    () async {
      final records = await family();
      expect(await repository.publishRestored(records.successor), isA<Ok>());
      final previous =
          (await repository.getByWalletId(records.previous.walletId)
                  as Ok<BullVaultRecord?, BullVaultFailure>)
              .value!;
      expect(previous.successorWalletId, records.successor.walletId);
      expect(previous.status, BullVaultLifecycleStatus.migrating);
      final hidden =
          (await (database.select(database.walletMetadatas)
                    ..where((row) => row.id.equals(records.successor.walletId)))
                  .getSingle())
              .isHidden;
      expect(hidden, isFalse);
    },
  );
  test(
    'a failed recovered link rolls back publication and can be retried',
    () async {
      final records = await family();
      await database.customStatement(
        "CREATE TRIGGER fail_recovered_link BEFORE UPDATE ON bull_vault_records WHEN OLD.wallet_id = 'previous' BEGIN SELECT RAISE(ABORT, 'fixture'); END",
      );
      expect(await repository.publishRestored(records.successor), isA<Err>());
      expect(
        (await repository.getByWalletId(records.successor.walletId) as Ok)
            .value,
        isNull,
      );
      expect(
        (await owner.load(records.previous.walletId))!.successorWalletId,
        isNull,
      );
      await database.customStatement('DROP TRIGGER fail_recovered_link');
      expect(await repository.publishRestored(records.successor), isA<Ok>());
    },
  );
}
