import 'dart:io';

import 'package:bull_recoverbull/migration.dart';
import 'package:bull_recoverbull/storage.dart';
import 'package:bull_recoverbull/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'admitted owners import their usages once and retain subsequent changes',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'wallet-backups-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/legacy.sqlite');
      final source = LegacySource(file, splitV1SourceSchemaVersion);
      final db = sqlite3.open(file.path);
      db.userVersion = source.schemaVersion;
      db.execute('''
      CREATE TABLE wallet_metadatas (
        id TEXT PRIMARY KEY, network TEXT, signer TEXT, master_fingerprint TEXT,
        is_encrypted_vault_tested INTEGER, is_physical_backup_tested INTEGER,
        latest_encrypted_backup INTEGER, latest_physical_backup INTEGER
      )
    ''');
      db.execute('''
      INSERT INTO wallet_metadatas VALUES
        ('test', 'bitcoinTestnet', 'local', '12345678', 1, 0, 10, NULL),
        ('reg', 'liquidRegtest', 'local', '12345678', 0, 1, NULL, 11),
        ('shared', 'liquidTestnet', 'local', '12345678', 0, 0, NULL, NULL),
        ('other', 'bitcoinTestnet', 'local', 'abcdef01', 0, 0, NULL, NULL),
        ('watch', 'bitcoinMainnet', 'remote', '12345678', 0, 1, NULL, 12)
    ''');
      db.close();
      final gate = NativeFileGate(File('${directory.path}/gate'));
      final owners = [
        for (final regtest in [false, true])
          recoverBullCutoverForTesting(
            file: File('${directory.path}/recoverbull-$regtest.sqlite'),
            standalone: File('${directory.path}/standalone-$regtest.sqlite'),
            regtest: regtest,
          ),
      ];
      final exclusive = await gate.acquire(
        exclusive: true,
        timeout: Duration.zero,
      ) as ExclusiveAdmission;
      try {
        for (final owner in owners) {
          final prepared = _ok(
            await owner.participant.prepare(exclusive, OwnerOrigin.legacy),
          );
          _ok(await prepared.importLegacy(source));
          _ok(await prepared.close());
        }
      } finally {
        await exclusive.close();
      }
      final admission = await gate.acquire(
        exclusive: false,
        timeout: Duration.zero,
      ) as RuntimeAdmission;
      addTearDown(admission.close);
      Future<RecoverBullWalletBackups> open(RecoverBullCutover owner) async =>
          _ok(
            await RecoverBullWalletBackups.open(
              cutover: owner,
              admission: admission,
              legacy: source,
            ),
          );
      final invalid = sqlite3.open(file.path);
      invalid.execute(
        "UPDATE wallet_metadatas SET is_physical_backup_tested = 2 WHERE id = 'watch'",
      );
      invalid.close();
      expect(
        await RecoverBullWalletBackups.open(
          cutover: owners.first,
          admission: admission,
          legacy: source,
        ),
        isA<Err>(),
      );
      final repaired = sqlite3.open(file.path);
      repaired.execute(
        "UPDATE wallet_metadatas SET is_physical_backup_tested = 1 WHERE id = 'watch'",
      );
      repaired.close();
      final initialBytes = await file.readAsBytes();
      final main = await open(owners.first);
      final reg = await open(owners.last);
      expect(_ok(await main.read('reg')), isNull);
      expect(_ok(await reg.read('test')), isNull);
      final watchOnly = _ok(await main.read('watch'));
      expect(watchOnly?.latestPhysicalBackup, 12);
      expect(watchOnly?.secretFingerprint, isNull);
      final fingerprint = Fingerprint('12345678');
      expect(
        _ok(await main.projection(fingerprint)).physicalBackupTested,
        isFalse,
      );
      expect(_ok(await reg.projection(fingerprint)).latestPhysicalBackup, 11);
      expect(await file.readAsBytes(), initialBytes);
      expect(
        await main.recordPhysicalVerification(
          walletId: 'other',
          fingerprint: fingerprint,
        ),
        isA<Err>(),
      );
      expect(
        _ok(await main.projection(fingerprint)).physicalBackupTested,
        isFalse,
      );
      _ok(
        await main.recordPhysicalVerification(
          walletId: 'test',
          fingerprint: fingerprint,
        ),
      );
      final recorded = _ok(await main.read('test'));
      expect(recorded?.latestPhysicalBackup, isNotNull);
      expect(recorded?.latestEncryptedBackup, 10);
      expect(recorded?.encryptedVaultTested, isTrue);
      expect(
        _ok(await main.read('shared'))?.latestPhysicalBackup,
        recorded?.latestPhysicalBackup,
      );
      expect(_ok(await main.read('other'))?.physicalBackupTested, isFalse);
      expect(_ok(await main.read('watch')), watchOnly);
      expect(_ok(await reg.read('reg'))?.latestPhysicalBackup, 11);
      _ok(await main.remove('test'));
      _ok(
        await reg.write((
          walletId: 'reg',
          secretFingerprint: fingerprint.hex,
          encryptedVaultTested: true,
          physicalBackupTested: true,
          latestEncryptedBackup: 13,
          latestPhysicalBackup: 11,
        )),
      );
      await main.close();
      await reg.close();
      await file.delete();
      expect(_ok(await (await open(owners.first)).read('test')), isNull);
      expect(
        _ok(await (await open(owners.last)).projection(fingerprint))
            .latestEncryptedBackup,
        13,
      );
    },
  );
}

T _ok<T, F extends Failure>(Result<T, F> result) => result.fold(
  (value) => value,
  (failure) => fail('Unexpected ${failure.runtimeType}'),
);
