import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_signer_device_port.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/wallet_backup/data/bullvault_backup_repository_impl.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/bullvault_backup_entry.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_inventory_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/manage_bullvault_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../bullvault/bullvault_test_fixture.dart';

class _Vaults extends Mock implements BullVaultFacade {}

class _Devices extends Mock implements WalletSignerDevicePort {}

void main() {
  late SqliteDatabase database;
  late _Vaults vaults;
  late CaptureBullVaultBackupUsecase capture;
  late RestoreBullVaultBackupUsecase restore;
  final old = testBullVaultCreateResult(
    walletId: 'old-source',
    status: BullVaultLifecycleStatus.migrating,
  );
  final current = testBullVaultCreateResult(
    walletId: 'new-source',
    previousVaultId: 'old-source',
    generation: 1,
    lineageId: old.record.lineageId,
    status: BullVaultLifecycleStatus.active,
  );
  final records = [old.record, current.record];
  final entries = [
    for (final record in records)
      BullVaultBackupEntry(
        reference: record.walletId,
        status: record.status,
        recoveryPackage: record.recoveryPackage,
      ),
  ];
  final wallets = [
    for (final record in records)
      BackupWallet(
        reference: record.walletId,
        network: record.recoveryPackage.policy.network,
        publicDescriptor: record.recoveryPackage.policy.descriptor,
        signers: [],
        isDefault: false,
        isHidden: false,
        label: 'Vault name',
      ),
  ];
  final submitted = <BullVaultRecoveryPackage>[];
  setUpAll(() => registerFallbackValue(old.record.recoveryPackage));
  setUp(() {
    database = SqliteDatabase(NativeDatabase.memory());
    vaults = _Vaults();
    submitted.clear();
    when(
      vaults.listRecords,
    ).thenAnswer((_) async => Ok(records.reversed.toList()));
    when(() => vaults.encodeRecoveryPackage(any())).thenAnswer((call) {
      submitted.add(
        call.positionalArguments.single as BullVaultRecoveryPackage,
      );
      return 'package-${submitted.length}';
    });
    when(
      () => vaults.restoreFromRecoveryPackage(
        source: any(named: 'source'),
        label: any(named: 'label'),
        status: any(named: 'status'),
        network: any(named: 'network'),
      ),
    ).thenAnswer((call) async {
      final isOld = submitted.last.policy.vaultGeneration == 0;
      final created = isOld ? old : current;
      expect(call.namedArguments[#status], created.record.status);
      expect(call.namedArguments[#label], 'Vault name');
      return Ok(
        BullVaultRestoreResult(
          wallet: created.wallet.copyWith(
            origin: isOld ? 'old-target' : 'new-target',
          ),
          record: created.record,
          mobileAccess: BullVaultMobileAccess.unavailable,
        ),
      );
    });
    final repository = BullVaultBackupRepositoryImpl(
      database: database,
      vaults: vaults,
      wallets: WalletMetadataDatasource(sqlite: database),
      signerDevices: _Devices(),
    );
    capture = CaptureBullVaultBackupUsecase(repository);
    restore = RestoreBullVaultBackupUsecase(repository);
  });
  tearDown(() => database.close());
  test(
    'captures every lifecycle record with native packages and no local test receipts',
    () async {
      final result = await capture.execute({
        'old-source': 'old-source',
        'new-source': 'new-source',
      });
      final value =
          (result as Ok<List<BullVaultBackupEntry>, WalletBackupFailure>).value;
      expect(value.map((e) => e.status).toSet(), {
        BullVaultLifecycleStatus.migrating,
        BullVaultLifecycleStatus.active,
      });
      expect(value.map((e) => e.reference).toSet(), {
        'old-source',
        'new-source',
      });
    },
  );
  test(
    'missing manifest wallet or unreadable vault inventory is incomplete',
    () async {
      expect(await capture.execute({'old-source': 'old-source'}), isA<Err>());
      when(
        vaults.listRecords,
      ).thenAnswer((_) async => const Err(BullVaultInvalidRecoveryFailure()));
      expect(await capture.execute({}), isA<Err>());
    },
  );
  test(
    'restores oldest first and remaps predecessor IDs before invoking the vault owner',
    () async {
      final result =
          (await restore.execute(entries.reversed.toList(), wallets)
                  as Ok<WalletInventoryRecovery, WalletBackupFailure>)
              .value;
      expect(result.complete, isTrue);
      expect(result.walletReferences, {
        'old-source': 'old-target',
        'new-source': 'new-target',
      });
      expect(submitted.first.previousVaultId, isNull);
      expect(submitted.last.previousVaultId, 'old-target');
    },
  );
  test(
    'missing predecessor and mismatched descriptor reject before the first mutation',
    () async {
      expect(await restore.execute([entries.last], wallets), isA<Err>());
      final wrong = BackupWallet(
        reference: wallets.first.reference,
        network: wallets.first.network,
        publicDescriptor: 'different',
        signers: [],
        isDefault: false,
        isHidden: false,
      );
      expect(await restore.execute(entries, [wrong, wallets.last]), isA<Err>());
      expect(submitted, isEmpty);
    },
  );
  test(
    'failed predecessor prevents its successor and reports both incomplete',
    () async {
      when(
        () => vaults.restoreFromRecoveryPackage(
          source: any(named: 'source'),
          label: any(named: 'label'),
          status: any(named: 'status'),
          network: any(named: 'network'),
        ),
      ).thenAnswer((_) async => const Err(BullVaultInvalidRecoveryFailure()));
      final result =
          (await restore.execute(entries, wallets)
                  as Ok<WalletInventoryRecovery, WalletBackupFailure>)
              .value;
      expect(result.failedReferences, ['old-source', 'new-source']);
      expect(submitted, hasLength(1));
    },
  );
}
