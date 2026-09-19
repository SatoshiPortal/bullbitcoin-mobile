import 'package:bb_mobile/core/seed/domain/seed_verification_port.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_signer_device_port.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/wallet_backup/data/wallet_inventory_backup_repository_impl.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/bullvault_backup_entry.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_inventory_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../bullvault/bullvault_test_fixture.dart';

class _Vaults extends Mock implements BullVaultFacade {}

class _Devices extends Mock implements WalletSignerDevicePort {}

class _Seeds extends Fake implements SeedVerificationPort {}

class _Descriptors extends Fake implements BitcoinDescriptorPort {}

void main() {
  late SqliteDatabase database;
  late _Vaults vaults;
  late WalletInventoryBackupRepositoryImpl repository;
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
    repository = WalletInventoryBackupRepositoryImpl(
      database: database,
      seeds: _Seeds(),
      descriptors: _Descriptors(),
      vaults: vaults,
      wallets: WalletMetadataDatasource(sqlite: database),
      signerDevices: _Devices(),
    );
  });
  tearDown(() => database.close());
  test(
    'captures every lifecycle record with native packages and no local test receipts',
    () async {
      final result = await repository.captureVaults({
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
      expect(
        await repository.captureVaults({'old-source': 'old-source'}),
        isA<Err>(),
      );
      when(
        vaults.listRecords,
      ).thenAnswer((_) async => const Err(BullVaultInvalidRecoveryFailure()));
      expect(await repository.captureVaults({}), isA<Err>());
    },
  );
  test(
    'restores oldest first and remaps predecessor IDs before invoking the vault owner',
    () async {
      final result =
          (await repository.restoreVaults(entries.reversed.toList(), wallets)
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
      expect(
        await repository.restoreVaults([entries.last], wallets),
        isA<Err>(),
      );
      final wrong = BackupWallet(
        reference: wallets.first.reference,
        network: wallets.first.network,
        publicDescriptor: 'different',
        signers: [],
        isDefault: false,
        isHidden: false,
      );
      expect(
        await repository.restoreVaults(entries, [wrong, wallets.last]),
        isA<Err>(),
      );
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
          (await repository.restoreVaults(entries, wallets)
                  as Ok<WalletInventoryRecovery, WalletBackupFailure>)
              .value;
      expect(result.failedReferences, ['old-source', 'new-source']);
      expect(submitted, hasLength(1));
    },
  );
  test(
    'abandoning after one vault stops later imports and reports unfinished references',
    () async {
      final result =
          (await repository.restoreVaults(
                    entries,
                    wallets,
                    abandoned: () => submitted.isNotEmpty,
                  )
                  as Ok<WalletInventoryRecovery, WalletBackupFailure>)
              .value;
      expect(submitted, hasLength(1));
      expect(result.walletReferences, {'old-source': 'old-target'});
      expect(result.failedReferences, ['new-source']);
    },
  );
  test(
    'a vault without a saved label uses its public reference for the existing importer',
    () async {
      final source = wallets.first;
      final unnamed = BackupWallet(
        reference: source.reference,
        network: source.network,
        publicDescriptor: source.publicDescriptor,
        signers: [],
        isDefault: false,
        isHidden: false,
      );
      when(
        () => vaults.restoreFromRecoveryPackage(
          source: any(named: 'source'),
          label: any(named: 'label'),
          status: any(named: 'status'),
          network: any(named: 'network'),
        ),
      ).thenAnswer((call) async {
        expect(call.namedArguments[#label], source.reference);
        return Ok(
          BullVaultRestoreResult(
            wallet: old.wallet,
            record: old.record,
            mobileAccess: BullVaultMobileAccess.unavailable,
          ),
        );
      });
      final result = await repository.restoreVaults([entries.first], [unnamed]);
      expect(
        (result as Ok<WalletInventoryRecovery, WalletBackupFailure>)
            .value
            .complete,
        isTrue,
      );
    },
  );
}
