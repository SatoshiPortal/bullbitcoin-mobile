import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
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
  late BullVaultMetadataDatasource datasource;
  late BullVaultRecordMapper mapper;
  late BullVaultRepositoryImpl repository;
  late BullVaultRecord original;
  final time = DateTime.utc(2026, 9, 18, 10);

  setUp(() async {
    database = SqliteDatabase(NativeDatabase.memory());
    datasource = BullVaultMetadataDatasource(database);
    final codec = testBullVaultRecoveryPackageCodec();
    mapper = BullVaultRecordMapper(codec);
    repository = BullVaultRepositoryImpl(datasource, mapper, codec);
    original = testBullVaultCreateResult(walletId: 'vault').record;
    await database
        .into(database.walletMetadatas)
        .insert(
          WalletMetadatasCompanion.insert(
            id: original.walletId,
            network: Network.bitcoinMainnet,
            publicDescriptor: original.recoveryPackage.policy.descriptor,
            isEncryptedVaultTested: false,
            isPhysicalBackupTested: false,
            isDefault: false,
          ),
        );
    await datasource.save(mapper.toModel(original));
  });
  tearDown(() => database.close());

  Future<BullVaultRecord> read() async =>
      (await repository.getByWalletId('vault')
              as Ok<BullVaultRecord?, BullVaultFailure>)
          .value!;

  test(
    'manual and server checks persist independently on the selected package',
    () async {
      expect(
        await repository.recordBackupTest(
          expected: original,
          kind: BullVaultBackupTestKind.descriptor,
          testedAt: time,
        ),
        isA<Ok>(),
      );
      expect((await read()).descriptorTestedAt, time);
      expect((await read()).serverTestedAt, isNull);
      expect(
        await repository.recordBackupTest(
          expected: original,
          kind: BullVaultBackupTestKind.server,
          testedAt: time.add(const Duration(minutes: 1)),
        ),
        isA<Ok>(),
      );
      final reopened = BullVaultRecordMapper(
        testBullVaultRecoveryPackageCodec(),
      ).toEntity((await BullVaultMetadataDatasource(database).load('vault'))!);
      expect(reopened.descriptorTestedAt, time);
      expect(reopened.serverTestedAt, time.add(const Duration(minutes: 1)));
      // A save from before the check must not erase these receipts.
      await datasource.save(mapper.toModel(original));
      expect((await read()).descriptorTestedAt, time);
      expect((await read()).serverTestedAt, reopened.serverTestedAt);
    },
  );

  test(
    'changed packages clear local dates and reject stale check results',
    () async {
      expect(
        await repository.recordBackupTest(
          expected: original,
          kind: BullVaultBackupTestKind.descriptor,
          testedAt: time,
        ),
        isA<Ok>(),
      );
      final changed = testBullVaultCreateResult(
        walletId: 'vault',
        lineageId: original.lineageId,
        includesInheritance: true,
      ).record;
      await datasource.save(mapper.toModel(changed));
      expect((await read()).descriptorTestedAt, isNull);
      expect(
        await repository.recordBackupTest(
          expected: original,
          kind: BullVaultBackupTestKind.server,
          testedAt: time,
        ),
        isA<Err>(),
      );
      expect((await read()).serverTestedAt, isNull);
    },
  );

  test(
    'deleting a vault removes its dates and a late check cannot recreate it',
    () async {
      expect(
        await repository.recordBackupTest(
          expected: original,
          kind: BullVaultBackupTestKind.descriptor,
          testedAt: time,
        ),
        isA<Ok>(),
      );
      await datasource.delete('vault');
      expect(
        await repository.recordBackupTest(
          expected: original,
          kind: BullVaultBackupTestKind.server,
          testedAt: time,
        ),
        isA<Err>(),
      );
      expect(await datasource.load('vault'), isNull);
      await datasource.save(mapper.toModel(original));
      expect((await read()).descriptorTestedAt, isNull);
    },
  );
}
