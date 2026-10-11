import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_metadata_datasource.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_record_mapper.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_repository_impl.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/load_bullvault_menu_usecase.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../bullvault_test_fixture.dart';

class _Settings extends Mock implements GetSettingsUsecase {}

class _NoRecordsRead extends Fake implements BullVaultRepository {}

void main() {
  late SqliteDatabase database;
  late BullVaultRepositoryImpl repository;
  late _Settings settings;
  setUp(() {
    database = SqliteDatabase(NativeDatabase.memory());
    final codec = testBullVaultRecoveryPackageCodec();
    repository = BullVaultRepositoryImpl(
      BullVaultMetadataDatasource(database),
      BullVaultRecordMapper(codec),
      codec,
    );
    settings = _Settings();
    when(settings.execute).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );
  });
  tearDown(() => database.close());
  Future<void> save(
    String id, {
    Network network = Network.bitcoinMainnet,
    BullVaultLifecycleStatus status = BullVaultLifecycleStatus.active,
    int year = 2026,
  }) async {
    final original = testBullVaultCreateResult(
      walletId: id,
      lineageId: 'lineage-$id',
      network: network,
      status: status,
      usesBullMobile: false,
    ).record;
    final record = BullVaultRecord(
      walletId: id,
      lineageId: original.lineageId,
      vaultGeneration: original.vaultGeneration,
      mobileAccount: null,
      birthHeight: original.birthHeight,
      recoveryPackage: original.recoveryPackage,
      status: status,
      createdAt: DateTime.utc(year),
    );
    await database
        .into(database.walletMetadatas)
        .insert(
          WalletMetadatasCompanion.insert(
            id: id,
            network: network,
            publicDescriptor: record.recoveryPackage.policy.descriptor,
            isEncryptedVaultTested: false,
            isPhysicalBackupTested: false,
            isDefault: false,
          ),
        );
    expect(await repository.save(record), isA<Ok>());
  }

  test(
    'lists current-network records newest first, including pending and historical vaults',
    () async {
      await save('old', status: .migrating, year: 2024);
      await save('cancelled', status: .cancelled);
      await save('testnet', network: Network.bitcoinTestnet);
      await save('pending', status: .pending, year: 2027);
      final usecase = LoadBullVaultMenuUsecase(repository, settings);
      final result = await usecase.execute();
      expect(
        (result as Ok<List<BullVaultRecord>, BullVaultFailure>).value.map(
          (record) => record.walletId,
        ),
        ['pending', 'old'],
      );
      when(settings.execute).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.testnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      );
      final switched = await usecase.execute();
      expect(
        (switched as Ok<List<BullVaultRecord>, BullVaultFailure>).value.map(
          (record) => record.walletId,
        ),
        ['testnet'],
      );
    },
  );
  test(
    'empty is successful; corrupt stored data remains a visible failure',
    () async {
      final usecase = LoadBullVaultMenuUsecase(repository, settings);
      final empty = await usecase.execute();
      expect(
        (empty as Ok<List<BullVaultRecord>, BullVaultFailure>).value,
        isEmpty,
      );
      await save('broken');
      await database
          .update(database.bullVaultRecords)
          .write(
            const BullVaultRecordsCompanion(recoveryPackage: Value('{invalid')),
          );
      expect(
        await usecase.execute(),
        isA<Err<List<BullVaultRecord>, BullVaultFailure>>(),
      );
    },
  );
  test('settings failure cannot silently fall back to mainnet', () async {
    when(settings.execute).thenThrow(Exception('settings unavailable'));
    expect(
      await LoadBullVaultMenuUsecase(_NoRecordsRead(), settings).execute(),
      isA<Err>(),
    );
  });
}
