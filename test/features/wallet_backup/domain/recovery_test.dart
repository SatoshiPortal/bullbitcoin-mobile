import 'dart:io';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/data/drift_wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/bullvault_backup_entry.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_inventory_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/bullvault_backup_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_codec_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_inventory_backup_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_metadata_backup_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/apply_wallet_backup_snapshot_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../backup_snapshot_fixture.dart';
import '../../bullvault/bullvault_test_fixture.dart';

class _Catalog extends Mock implements KeychainManifestFacade {}

class _Wallets extends Mock implements WalletInventoryBackupRepository {}

class _Vaults extends Mock implements BullVaultBackupRepository {}

class _Metadata extends Mock implements WalletMetadataBackupRepository {}

class _Codec extends Mock implements WalletBackupCodecRepository {}

T value<T>(Result<T, WalletBackupFailure> result) =>
    (result as Ok<T, WalletBackupFailure>).value;

void main() {
  final credential = BackupCredential.fromWords(backupFixtureWords);
  final snapshot = backupSnapshotFixture(credential);
  late Directory directory;
  late File file;
  late SqliteDatabase database;
  late DriftWalletBackupStateRepository state;
  late _Catalog catalog;
  late _Wallets wallets;
  late _Vaults vaults;
  late _Metadata metadata;
  late _Codec codec;
  late ApplyWalletBackupSnapshotUsecase apply;
  final stages = <String>[];

  void configure() {
    apply = ApplyWalletBackupSnapshotUsecase(
      state: state,
      codec: codec,
      catalog: catalog,
      wallets: wallets,
      vaults: vaults,
      metadata: metadata,
    );
  }

  Future<void> stage(String name) async {
    expect(value(await state.getControl()).recoveryIncomplete, isTrue);
    stages.add(name);
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('bull-backup-recovery-');
    file = File('${directory.path}/state.sqlite');
    database = SqliteDatabase(NativeDatabase(file));
    state = DriftWalletBackupStateRepository(database);
    catalog = _Catalog();
    wallets = _Wallets();
    vaults = _Vaults();
    metadata = _Metadata();
    codec = _Codec();
    stages.clear();
    when(
      () => codec.encode(snapshot),
    ).thenReturn(const Ok('validated fixture'));
    when(() => codec.decode('validated fixture')).thenReturn(Ok(snapshot));
    when(() => catalog.restorePublicRecords(snapshot.manifest)).thenAnswer((
      _,
    ) async {
      await stage('catalog');
      return const Ok(null);
    });
    when(() => wallets.restore(snapshot.manifest.wallets)).thenAnswer((
      _,
    ) async {
      await stage('wallets');
      return Ok(
        WalletInventoryRecovery(
          walletReferences: {'source-wallet': 'target-wallet'},
          failedReferences: [],
        ),
      );
    });
    when(
      () => vaults.restore(snapshot.vaults, snapshot.manifest.wallets),
    ).thenAnswer((_) async {
      await stage('vaults');
      return Ok(
        WalletInventoryRecovery(walletReferences: {}, failedReferences: []),
      );
    });
    when(
      () =>
          metadata.apply(snapshot.metadata, {'source-wallet': 'target-wallet'}),
    ).thenAnswer((_) async {
      await stage('metadata');
      return const Ok(null);
    });
    configure();
  });
  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test('validation happens before any fence or owner write', () async {
    when(
      () => codec.decode('validated fixture'),
    ).thenReturn(const Err(WalletBackupInvalidFailure()));
    expect(await apply.execute(snapshot), isA<Err>());
    expect(stages, isEmpty);
    expect(value(await state.getControl()).recoveryIncomplete, isFalse);
  });

  test(
    'BullVault entries go only through the vault owner and join the reference map',
    () async {
      final record = testBullVaultCreateResult(
        walletId: 'source-vault',
        status: BullVaultLifecycleStatus.active,
      ).record;
      final source = WalletBackupSnapshot(
        manifest: KeychainManifest(
          sourceFingerprint: snapshot.manifest.sourceFingerprint,
          wallets: [
            ...snapshot.manifest.wallets,
            BackupWallet(
              reference: record.walletId,
              network: record.recoveryPackage.policy.network,
              publicDescriptor: record.recoveryPackage.policy.descriptor,
              signers: [],
              isDefault: false,
              isHidden: false,
              label: 'Vault',
            ),
          ],
          derivations: snapshot.manifest.derivations,
          nostrKeys: snapshot.manifest.nostrKeys,
          backupIdentities: snapshot.manifest.backupIdentities,
        ),
        metadata: snapshot.metadata,
        vaults: [
          BullVaultBackupEntry(
            reference: record.walletId,
            status: record.status,
            recoveryPackage: record.recoveryPackage,
          ),
        ],
      );
      when(() => codec.encode(source)).thenReturn(const Ok('vault fixture'));
      when(() => codec.decode('vault fixture')).thenReturn(Ok(source));
      when(() => catalog.restorePublicRecords(source.manifest)).thenAnswer((
        _,
      ) async {
        await stage('catalog');
        return const Ok(null);
      });
      when(
        () => vaults.restore(source.vaults, source.manifest.wallets),
      ).thenAnswer((_) async {
        await stage('vaults');
        return Ok(
          WalletInventoryRecovery(
            walletReferences: {'source-vault': 'target-vault'},
            failedReferences: [],
          ),
        );
      });
      final mapping = {
        'source-wallet': 'target-wallet',
        'source-vault': 'target-vault',
      };
      when(() => metadata.apply(source.metadata, mapping)).thenAnswer((
        _,
      ) async {
        await stage('metadata');
        return const Ok(null);
      });
      final result = value(await apply.execute(source));
      expect(result.complete, isTrue);
      expect(result.wallets.walletReferences, mapping);
      verify(() => wallets.restore(snapshot.manifest.wallets)).called(1);
    },
  );

  test(
    'all owners see the durable fence; completion preserves consent and remaps references',
    () async {
      value(await state.setEnabled(false));
      final result = value(await apply.execute(snapshot));
      expect(result.complete, isTrue);
      expect(result.wallets.walletReferences, {
        'source-wallet': 'target-wallet',
      });
      expect(stages, ['catalog', 'wallets', 'vaults', 'metadata']);
      final control = value(await state.getControl());
      expect(control.recoveryIncomplete, isFalse);
      expect(control.enabled, isFalse);
    },
  );

  test('failure to persist the fence prevents every mutation', () async {
    await database.customStatement(
      "CREATE TRIGGER fail_fence BEFORE INSERT ON wallet_backup_controls BEGIN SELECT RAISE(ABORT, 'fixture failure'); END",
    );
    expect(await apply.execute(snapshot), isA<Err>());
    expect(stages, isEmpty);
  });

  test(
    'partial wallet recovery survives reopen and a retry applies metadata only after completeness',
    () async {
      when(() => wallets.restore(snapshot.manifest.wallets)).thenAnswer((
        _,
      ) async {
        await stage('wallets');
        return Ok(
          WalletInventoryRecovery(
            walletReferences: {},
            failedReferences: ['source-wallet'],
          ),
        );
      });
      final partial = value(await apply.execute(snapshot));
      expect(partial.complete, isFalse);
      expect(partial.wallets.failedReferences, ['source-wallet']);
      expect(stages, isNot(contains('metadata')));
      await database.close();
      database = SqliteDatabase(NativeDatabase(file));
      state = DriftWalletBackupStateRepository(database);
      configure();
      expect(value(await state.getControl()).recoveryIncomplete, isTrue);
      when(() => wallets.restore(snapshot.manifest.wallets)).thenAnswer(
        (_) async => Ok(
          WalletInventoryRecovery(
            walletReferences: {'source-wallet': 'target-wallet'},
            failedReferences: [],
          ),
        ),
      );
      expect(value(await apply.execute(snapshot)).complete, isTrue);
      expect(value(await state.getControl()).recoveryIncomplete, isFalse);
    },
  );

  test(
    'metadata failure remains incomplete and does not change enablement',
    () async {
      value(await state.setEnabled(true));
      when(
        () => metadata.apply(snapshot.metadata, {
          'source-wallet': 'target-wallet',
        }),
      ).thenAnswer((_) async => const Err(WalletBackupStorageFailure()));
      final result = value(await apply.execute(snapshot));
      expect(result.complete, isFalse);
      expect(result.publicRecordsRestored, isTrue);
      expect(result.metadataRestored, isFalse);
      expect(value(await state.getControl()).recoveryIncomplete, isTrue);
      expect(value(await state.getControl()).enabled, isTrue);
      expect(
        value(await state.get(credential.serverPublicKey)).canPublish,
        isFalse,
      );
    },
  );

  test(
    'a remote head change at final verification keeps the recovery fence',
    () async {
      final result = value(
        await apply.execute(
          snapshot,
          revalidate: () async {
            await stage('revalidate');
            return const Ok(false);
          },
        ),
      );
      expect(result.metadataRestored, isTrue);
      expect(result.complete, isFalse);
      expect(result.failure, isA<WalletBackupConflictFailure>());
      expect(value(await state.getControl()).recoveryIncomplete, isTrue);
    },
  );

  test(
    'a requested recovery can finish after a previous incomplete attempt',
    () async {
      value(await state.setRecoveryIncomplete(true));
      expect(value(await apply.execute(snapshot)).complete, isTrue);
      expect(value(await state.getControl()).recoveryIncomplete, isFalse);
    },
  );

  test('catalog failure keeps the fence and prevents later mutation', () async {
    when(
      () => catalog.restorePublicRecords(snapshot.manifest),
    ).thenAnswer((_) async => const Err(KeychainManifestStorageFailure()));
    final result = value(await apply.execute(snapshot));
    expect(result.complete, isFalse);
    expect(result.publicRecordsRestored, isFalse);
    expect(stages, isEmpty);
    expect(value(await state.getControl()).recoveryIncomplete, isTrue);
  });

  test(
    'failure to clear the fence is reported and publication stays blocked',
    () async {
      value(await state.setRecoveryIncomplete(true));
      await database.customStatement(
        "CREATE TRIGGER fail_completion BEFORE UPDATE OF incomplete ON wallet_backup_controls WHEN NEW.incomplete = 0 BEGIN SELECT RAISE(ABORT, 'fixture failure'); END",
      );
      final result = value(await apply.execute(snapshot));
      expect(result.complete, isFalse);
      expect(result.metadataRestored, isTrue);
      expect(result.failure, isA<WalletBackupStorageFailure>());
      expect(value(await state.getControl()).recoveryIncomplete, isTrue);
    },
  );

  test(
    'incomplete owner results cannot silently omit a required wallet',
    () async {
      when(() => wallets.restore(snapshot.manifest.wallets)).thenAnswer(
        (_) async => Ok(
          WalletInventoryRecovery(walletReferences: {}, failedReferences: []),
        ),
      );
      final result = value(await apply.execute(snapshot));
      expect(result.complete, isFalse);
      expect(result.wallets.failedReferences, ['source-wallet']);
      expect(stages, isNot(contains('metadata')));
      expect(value(await state.getControl()).recoveryIncomplete, isTrue);
    },
  );
}
