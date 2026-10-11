import 'package:bb_mobile/core/seed/domain/seed_verification_port.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/wallet/data/mappers/wallet_signer_mapper.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/data/wallet_network_codec.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:primitives/primitives.dart' show Err, Ok;
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
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
  late _Devices devices;
  late WalletMetadataDatasource metadata;
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
    devices = _Devices();
    metadata = WalletMetadataDatasource(sqlite: database);
    submitted.clear();
    when(vaults.listRecords)
        .thenAnswer((_) async => Ok(records.reversed.toList()));
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
      wallets: metadata,
      signerDevices: devices,
    );
  });
  tearDown(() => database.close());
  test('captures every lifecycle record with native packages and no local test receipts', () async {
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
    expect(value.map((e) => e.reference).toSet(), {'old-source', 'new-source'});
  });
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
  test('restores oldest first and remaps predecessor IDs before invoking the vault owner', () async {
    final result = (await repository.restoreVaults(
      entries.reversed.toList(),
      wallets,
    ) as Ok<WalletInventoryRecovery, WalletBackupFailure>).value;
    expect(result.complete, isTrue);
    expect(result.walletReferences, {
      'old-source': 'old-target',
      'new-source': 'new-target',
    });
    expect(submitted.first.previousVaultId, isNull);
    expect(submitted.last.previousVaultId, 'old-target');
  });
  test(
    'retry completes missing signer hints without replacing local preferences',
    () async {
      final source = wallets.first;
      final account = old.record.recoveryPackage.policy.coldKey.accountKey;
      final signer = WalletSigner(
        id: 'cold',
        signer: SignerEntity.remote,
        signerDevice: null,
        descriptorKeys: [
          WalletDescriptorKey(
            id: 'cold-key',
            signerId: 'cold',
            masterFingerprint: account.masterFingerprint,
            xpubFingerprint: account.xpubFingerprint,
            xpub: account.xpub,
            derivationPath: account.derivationPath,
          ),
        ],
      );
      final annotated = BackupWallet(
        reference: source.reference,
        network: source.network,
        publicDescriptor: source.publicDescriptor,
        signers: [signer.copyWith(registrationName: 'Saved vault')],
        isDefault: false,
        isHidden: false,
        label: source.label,
        birthday: DateTime.utc(2020),
      );
      when(
        () => vaults.restoreFromRecoveryPackage(
          source: any(named: 'source'),
          label: any(named: 'label'),
          status: any(named: 'status'),
          network: any(named: 'network'),
        ),
      ).thenAnswer((_) async {
        if (await metadata.fetch('old-target') == null) {
          await metadata.insert(
            WalletMetadataModel(
              id: 'old-target',
              networkCode: WalletNetworkCodec.encode(source.network),
              signers: [signer.toModel()],
              publicDescriptor: source.publicDescriptor,
              isDefault: false,
              isEncryptedVaultTested: false,
              isPhysicalBackupTested: false,
              label: source.label,
            ),
          );
        }
        return Ok(
          BullVaultRestoreResult(
            wallet: old.wallet.copyWith(origin: 'old-target'),
            record: old.record,
            mobileAccess: BullVaultMobileAccess.unavailable,
          ),
        );
      });
      var attempts = 0;
      when(
        () => devices.updateSignerRegistrationName(
          walletId: 'old-target',
          signerId: 'cold',
          registrationName: 'Saved vault',
        ),
      ).thenAnswer((_) async {
        if (++attempts == 1) throw const FormatException('storage unavailable');
        await metadata.updateSignerRegistrationName(
          walletId: 'old-target',
          signerId: 'cold',
          registrationName: 'Saved vault',
        );
        return old.wallet;
      });
      final first = await repository.restoreVaults(
        [entries.first],
        [annotated],
      );
      expect(
        (first as Ok<WalletInventoryRecovery, WalletBackupFailure>)
            .value
            .complete,
        isFalse,
      );
      final saved = await metadata.fetch('old-target');
      if (saved == null) fail('Imported vault must remain available for retry');
      await metadata.store(
        saved.copyWith(
          label: 'Edited locally',
          signers: [
            signer
                .copyWith(signerDevice: SignerDeviceEntity.ledgerFlex)
                .toModel(),
          ],
        ),
      );
      final retry = await repository.restoreVaults(
        [entries.first],
        [annotated],
      );
      expect(
        (retry as Ok<WalletInventoryRecovery, WalletBackupFailure>)
            .value
            .complete,
        isTrue,
      );
      final restored = await metadata.fetch('old-target');
      if (restored == null) fail('Expected restored vault');
      expect(restored.label, 'Edited locally');
      expect(restored.birthday, annotated.birthday);
      expect(
        restored.signers.single.toEntity().signerDevice,
        SignerDeviceEntity.ledgerFlex,
      );
      expect(restored.signers.single.registrationName, 'Saved vault');
    },
  );
  test('missing predecessor and mismatched descriptor reject before the first mutation', () async {
    expect(await repository.restoreVaults([entries.last], wallets), isA<Err>());
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
  });
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
      final result = (await repository.restoreVaults(
        entries,
        wallets,
      ) as Ok<WalletInventoryRecovery, WalletBackupFailure>).value;
      expect(result.failedReferences, ['old-source', 'new-source']);
      expect(submitted, hasLength(1));
    },
  );
  test('abandoning after one vault stops later imports and reports unfinished references', () async {
    final result = (await repository.restoreVaults(
      entries,
      wallets,
      abandoned: () => submitted.isNotEmpty,
    ) as Ok<WalletInventoryRecovery, WalletBackupFailure>).value;
    expect(submitted, hasLength(1));
    expect(result.walletReferences, {'old-source': 'old-target'});
    expect(result.failedReferences, ['new-source']);
  });
  test('a vault without a saved label uses its public reference for the existing importer', () async {
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
  });
}
