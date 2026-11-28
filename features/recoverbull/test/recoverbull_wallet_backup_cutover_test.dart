import 'dart:io';

import 'package:bull_recoverbull/migration.dart';
import 'package:bull_recoverbull/storage.dart';
import 'package:bull_recoverbull/testing.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/app_database.dart' show SqliteDatabase;
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart' show LegacyImportFailure;
import 'package:primitives/primitives.dart';

const _secondary = 'split-v1/recoverbull-wallet-backups';
const _mainReceipts = [
  'split-v1/recoverbull',
  'standalone-v1/recoverbull/absent',
];
const _regtestReceipts = ['split-v1/recoverbull_regtest'];

const _mainRows = <WalletBackupUsage>[
  (
    walletId: 'main-local',
    secretFingerprint: '12345678',
    encryptedVaultTested: true,
    physicalBackupTested: false,
    latestEncryptedBackup: 10,
    latestPhysicalBackup: null,
  ),
  (
    walletId: 'main-watch',
    secretFingerprint: null,
    encryptedVaultTested: false,
    physicalBackupTested: true,
    latestEncryptedBackup: null,
    latestPhysicalBackup: 12,
  ),
];
const _regtestRows = <WalletBackupUsage>[
  (
    walletId: 'reg-first',
    secretFingerprint: '12345678',
    encryptedVaultTested: false,
    physicalBackupTested: true,
    latestEncryptedBackup: null,
    latestPhysicalBackup: 21,
  ),
  (
    walletId: 'reg-second',
    secretFingerprint: '12345678',
    encryptedVaultTested: true,
    physicalBackupTested: false,
    latestEncryptedBackup: 22,
    latestPhysicalBackup: null,
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the two backup projections survive an interrupted second import', () async {
    final directory = await Directory.systemTemp.createTemp(
      'recoverbull-wallet-backup-cutover-',
    );
    addTearDown(() async {
      await LifecycleAdmission.retryQuarantined();
      await directory.delete(recursive: true);
    });
    File file(String name) => File('${directory.path}/$name.sqlite');
    final sourceFile = file('legacy');
    final seed = SqliteDatabase(NativeDatabase(sourceFile));
    try {
      await seed.customStatement('''
        INSERT INTO wallet_metadatas (
          id, network, signer, master_fingerprint, xpub_fingerprint,
          xpub, external_public_descriptor, internal_public_descriptor,
          is_default, is_encrypted_vault_tested, is_physical_backup_tested,
          latest_encrypted_backup, latest_physical_backup
        ) VALUES
          ('main-local', 'bitcoinMainnet', 'local', '12345678', '11111111',
           'fixture', 'fixture-external', 'fixture-internal', 0, 1, 0, 10, NULL),
          ('main-watch', 'bitcoinMainnet', 'remote', '12345678', '22222222',
           'fixture', 'fixture-external', 'fixture-internal', 0, 0, 1, NULL, 12),
          ('reg-first', 'bitcoinRegtest', 'local', '12345678', '33333333',
           'fixture', 'fixture-external', 'fixture-internal', 0, 0, 1, NULL, 21),
          ('reg-second', 'liquidRegtest', 'local', '12345678', '44444444',
           'fixture', 'fixture-external', 'fixture-internal', 0, 1, 0, 22, NULL)
      ''');
    } finally {
      await seed.close();
    }
    final legacy = LegacySource(
      sourceFile,
      SqliteDatabase.currentSchemaVersion,
    );
    // Keep the production admission and import paths, using the existing
    // file-backed executor fixture instead of the platform keystore.
    final mainnet = recoverBullCutoverForTesting(
      file: file('recoverbull'),
      standalone: file('standalone'),
    );
    final regtest = recoverBullCutoverForTesting(
      file: file('recoverbull_regtest'),
      standalone: file('standalone_regtest'),
      regtest: true,
    );
    final cutover = StorageCutover(
      directory: Directory('${directory.path}/coordination'),
      legacy: LegacySourceStore(source: legacy, create: SqliteDatabase.new),
      expectedOwners: {mainnet.ownerId, regtest.ownerId},
      participants: [mainnet.participant, regtest.participant],
    );

    await _ok(await cutover.prepare()).close();
    expect(
      await FileSystemEntity.identical(mainnet.file.path, regtest.file.path),
      isFalse,
    );
    final sourceFamily = {
      for (final suffix in ['', '-wal', '-shm', '-journal'])
        suffix: File('${sourceFile.path}$suffix'),
    };
    Map<String, List<int>?> sourceState() => sourceFamily.map(
      (suffix, file) =>
          MapEntry(suffix, file.existsSync() ? file.readAsBytesSync() : null),
    );
    final sourceBefore = sourceState();

    Future<void> withRuntime(
      Future<void> Function(RuntimeAdmission) exercise,
    ) async {
      final admission = _ok(await cutover.admit());
      try {
        await exercise(admission);
      } finally {
        await admission.close();
      }
      expect(sourceState(), sourceBefore);
    }

    Future<Result<RecoverBullWalletBackups, RecoverBullFailure>> openBackups(
      RecoverBullCutover owner,
      RuntimeAdmission admission,
    ) => RecoverBullWalletBackups.open(
      cutover: owner,
      admission: admission,
      legacy: legacy,
    );

    final gate = NativeFileGate(
      File('${cutover.directory.path}/lifecycle.lock'),
    );
    Future<Result<void, LegacyImportFailure>> verifyBothNetworks() async {
      final admission = await gate.acquire(
        exclusive: true,
        timeout: Duration.zero,
      ) as ExclusiveAdmission;
      try {
        return await RecoverBullRetirement(
          mainnet: mainnet,
          regtest: regtest,
        ).verifyRetirable(
          admission,
          origin: OwnerOrigin.legacy,
          source: legacy,
        );
      } finally {
        await admission.close();
      }
    }

    await withRuntime((admission) async {
      await _ok(await openBackups(mainnet, admission)).close();
      final store = _ok(await regtest.open(admission));
      try {
        // Only fail after the receipt and the first projected row are visible
        // inside this transaction. An earlier failure would not prove rollback.
        await store.database.customStatement('''
          CREATE TRIGGER reject_second_backup
          BEFORE INSERT ON recoverbull_wallet_backups
          WHEN NEW.wallet_id = 'reg-second'
            AND EXISTS (
              SELECT 1 FROM legacy_import_receipts WHERE id = '$_secondary'
            )
            AND EXISTS (
              SELECT 1 FROM recoverbull_wallet_backups WHERE wallet_id = 'reg-first'
            )
          BEGIN
            SELECT RAISE(ABORT, 'fixture second backup insert');
          END
        ''');
      } finally {
        await store.handle.close();
      }
    });
    expect(await verifyBothNetworks(), isA<Err>());

    await withRuntime((admission) async {
      expect(await openBackups(regtest, admission), isA<Err>());
      await _expectStore(mainnet, admission, [
        ..._mainReceipts,
        _secondary,
      ], _mainRows);
      await _expectStore(regtest, admission, _regtestReceipts, const []);
    });
    expect(await verifyBothNetworks(), isA<Err>());

    const newerRegtest = (
      walletId: 'reg-first',
      secretFingerprint: '12345678',
      encryptedVaultTested: true,
      physicalBackupTested: true,
      latestEncryptedBackup: 31,
      latestPhysicalBackup: 21,
    );
    await withRuntime((admission) async {
      final store = _ok(await regtest.open(admission));
      try {
        await store.database.customStatement(
          'DROP TRIGGER reject_second_backup',
        );
      } finally {
        await store.handle.close();
      }
      final backups = _ok(await openBackups(regtest, admission));
      try {
        for (final usage in _regtestRows) {
          expect(_ok(await backups.read(usage.walletId)), usage);
        }
        _ok(await writeWalletBackupForTesting(backups, newerRegtest));
      } finally {
        await backups.close();
      }
    });

    await withRuntime((admission) async {
      await _ok(await openBackups(mainnet, admission)).close();
      await _ok(await openBackups(regtest, admission)).close();
      await _expectStore(mainnet, admission, [
        ..._mainReceipts,
        _secondary,
      ], _mainRows);
      await _expectStore(
        regtest,
        admission,
        [..._regtestReceipts, _secondary],
        [newerRegtest, _regtestRows.last],
      );
    });
    expect(await verifyBothNetworks(), isA<Ok>());
    expect(sourceState(), sourceBefore);
  });
}

Future<void> _expectStore(
  RecoverBullCutover owner,
  RuntimeAdmission admission,
  List<String> receipts,
  List<WalletBackupUsage> usages,
) async {
  final store = _ok(await owner.open(admission));
  try {
    final database = store.database;
    final actualReceipts = await database
        .select(database.legacyImportReceipts)
        .get();
    expect(actualReceipts.map((row) => row.id), unorderedEquals(receipts));
    final actualUsages = await database
        .select(database.recoverbullWalletBackups)
        .get();
    expect(
      actualUsages.map(
        (row) => (
          walletId: row.walletId,
          secretFingerprint: row.secretFingerprint,
          encryptedVaultTested: row.encryptedVaultTested,
          physicalBackupTested: row.physicalBackupTested,
          latestEncryptedBackup: row.latestEncryptedBackup,
          latestPhysicalBackup: row.latestPhysicalBackup,
        ),
      ),
      unorderedEquals(usages),
    );
  } finally {
    await store.handle.close();
  }
}

T _ok<T, F extends Failure>(Result<T, F> result) => result.fold(
  (value) => value,
  (failure) => fail('Unexpected ${failure.runtimeType}'),
);
