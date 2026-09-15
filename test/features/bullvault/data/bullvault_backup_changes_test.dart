import 'dart:async';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bullvault/data/bip138_codec.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_metadata_datasource.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_record_mapper.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_repository_impl.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/watch_bullvault_backup_changes_usecase.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../bullvault_test_fixture.dart';

void main() {
  late SqliteDatabase database;
  late BullVaultMetadataDatasource datasource;
  late BullVaultRecordMapper mapper;
  late BullVaultRepositoryImpl repository;
  late StreamSubscription<void> subscription;
  late int notifications;

  Future<int> revision() async =>
      (await database.select(database.walletBackupStates).getSingleOrNull())
          ?.localRevision ??
      0;

  setUp(() async {
    database = SqliteDatabase(NativeDatabase.memory());
    datasource = BullVaultMetadataDatasource(database);
    final codec = testBullVaultRecoveryPackageCodec();
    mapper = BullVaultRecordMapper(codec);
    repository = BullVaultRepositoryImpl(
      datasource,
      mapper,
      codec,
      Bip138Codec(),
    );
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
              isHidden: const Value(true),
            ),
          );
    }
    notifications = 0;
    final initial = Completer<void>();
    subscription = WatchBullVaultBackupChangesUsecase(repository)
        .execute()
        .listen((_) {
          notifications++;
          if (!initial.isCompleted) initial.complete();
        });
    await initial.future;
    notifications = 0;
  });

  tearDown(() async {
    await subscription.cancel();
    await database.close();
  });

  test('no-op stores and local setup facts do not dirty the backup', () async {
    final record = testBullVaultCreateResult(walletId: 'first').record;
    expect(await repository.save(record), isA<Ok<void, BullVaultFailure>>());
    await pumpEventQueue();
    expect(await revision(), 1);
    expect(notifications, 1);
    expect(
      await repository.save(
        record.copyWith(
          hardwareSetupComplete: true,
          completedHardwareSignerIds: {'cold'},
          recoveryPackageConfirmed: true,
          mobileBackupDeferred: true,
        ),
      ),
      isA<Ok<void, BullVaultFailure>>(),
    );
    await repository.reserveNextGeneration(record);
    await repository.releaseGeneration(
      lineageId: record.lineageId,
      generation: 1,
    );
    await pumpEventQueue();
    expect(await revision(), 1);
    expect(notifications, 1);
    expect(await repository.delete('first'), isA<Ok<void, BullVaultFailure>>());
    await pumpEventQueue();
    expect(await revision(), 2);
    expect(notifications, 2);
    await repository.delete('first');
    await pumpEventQueue();
    expect(await revision(), 2);
    expect(notifications, 2);
  });

  test('each represented field records a revision and notification', () async {
    var model = mapper.toModel(
      testBullVaultCreateResult(walletId: 'first').record,
    );
    await datasource.save(model);
    final changes = <BullVaultRecordModel Function(BullVaultRecordModel)>[
      (row) => row.copyWith(status: 'active'),
      (row) => row.copyWith(lineageId: 'another-lineage'),
      (row) => row.copyWith(vaultGeneration: 1),
      (row) => row.copyWith(
        recoveryPackage: row.recoveryPackage.replaceFirst('3000000', '3000001'),
      ),
    ];
    await pumpEventQueue();
    for (var index = 0; index < changes.length; index++) {
      final changed = changes[index](model);
      expect(changed, isNot(model));
      model = changed;
      await datasource.save(model);
      await pumpEventQueue();
      expect(await revision(), index + 2);
      expect(notifications, index + 2);
    }
  });

  test(
    'outer rollback exposes neither the vault nor a backup change',
    () async {
      final inside = Completer<void>();
      final release = Completer<void>();
      final transaction = datasource.transaction(() async {
        await datasource.save(
          mapper.toModel(testBullVaultCreateResult(walletId: 'first').record),
        );
        inside.complete();
        await release.future;
        throw const FormatException('rollback fixture');
      });
      final failed = expectLater(transaction, throwsFormatException);
      await inside.future;
      await pumpEventQueue();
      expect(notifications, 0);
      release.complete();
      await failed;
      await pumpEventQueue();
      expect(await datasource.load('first'), isNull);
      expect(await revision(), 0);
      expect(notifications, 0);
    },
  );

  test('revision failure rolls the associated vault write back', () async {
    await database.customStatement('''
      CREATE TRIGGER fail_revision BEFORE UPDATE ON wallet_backup_states
      BEGIN SELECT RAISE(ABORT, 'revision unavailable'); END
    ''');
    expect(
      await repository.save(
        testBullVaultCreateResult(walletId: 'first').record,
      ),
      isA<Err<void, BullVaultFailure>>(),
    );
    await pumpEventQueue();
    expect(await datasource.load('first'), isNull);
    expect(await revision(), 0);
    expect(notifications, 0);
  });

  test(
    'renewal commits both generations and visibility or none of them',
    () async {
      final first = testBullVaultCreateResult(
        walletId: 'first',
        status: BullVaultLifecycleStatus.active,
      ).record;
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
      await repository.save(first);
      await repository.save(next);
      await pumpEventQueue();
      final beforeNotifications = notifications;
      final beforeRevision = await revision();
      await database.customStatement('''
      CREATE TRIGGER fail_visibility BEFORE UPDATE ON wallet_metadatas
      WHEN NEW.id = 'next' BEGIN SELECT RAISE(ABORT, 'visibility unavailable'); END
    ''');
      expect(
        await repository.activateRenewal(previous: first, replacement: next),
        isA<Err<void, BullVaultFailure>>(),
      );
      await pumpEventQueue();
      expect(await revision(), beforeRevision);
      expect(notifications, beforeNotifications);
      expect((await datasource.load('first'))!.status, 'active');
      expect((await datasource.load('next'))!.status, 'pending');
      await database.customStatement('DROP TRIGGER fail_visibility');
      expect(
        await repository.activateRenewal(previous: first, replacement: next),
        isA<Ok<void, BullVaultFailure>>(),
      );
      await pumpEventQueue();
      expect(await revision(), beforeRevision + 2);
      expect(notifications, beforeNotifications + 1);
      expect((await datasource.load('first'))!.status, 'migrating');
      expect((await datasource.load('next'))!.status, 'active');
      final rows = await database.select(database.walletMetadatas).get();
      expect(
        {for (final row in rows) row.id: row.isHidden},
        {'first': true, 'next': false},
      );
      await repository.activateRenewal(previous: first, replacement: next);
      await pumpEventQueue();
      expect(await revision(), beforeRevision + 2);
      expect(notifications, beforeNotifications + 1);
    },
  );
}
