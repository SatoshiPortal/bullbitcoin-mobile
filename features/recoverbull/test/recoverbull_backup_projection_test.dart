import 'package:bull_recoverbull/src/data/database/recoverbull_database.dart';
import 'package:bull_recoverbull/src/data/database/wallet_backup_import.dart';
import 'package:bull_recoverbull/src/data/attempt_monitoring_repository_impl.dart';
import 'package:bull_recoverbull/src/data/backup_metadata_repository_impl.dart';
import 'package:bull_recoverbull/src/domain/entities/backup_settings.dart';
import 'package:bull_recoverbull/src/domain/entities/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  test(
    'the configured server overrides the stored URL and cannot be edited',
    () async {
      final database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await database.forceOpen();
      final old = Uri.parse('http://old.onion');
      final configured = Uri.parse('http://configured.onion');
      final historical = BackupMetadataRepositoryImpl(database);
      expect(
        await historical.importLegacy(
          LegacyBackupSettings(server: old, permissionGranted: false),
        ),
        isA<Ok<void, RecoverBullFailure>>(),
      );

      final admitted = BackupMetadataRepositoryImpl(
        database,
        configuredServer: configured,
      );
      expect(
        await admitted.settings(),
        isA<Ok<BackupSettings, RecoverBullFailure>>()
            .having((result) => result.value.server, 'server', configured)
            .having((result) => result.value.serverEditable, 'editable', false),
      );
      expect(
        await admitted.changeServer(old),
        isA<Err<void, RecoverBullFailure>>(),
      );
      expect(
        await admitted.acceptServer(old),
        isA<Err<void, RecoverBullFailure>>(),
      );
      expect(
        await admitted.acceptServer(configured),
        isA<Ok<void, RecoverBullFailure>>(),
      );

      final monitoring = AttemptMonitoringRepositoryImpl(
        database,
        durable: true,
        configuredServer: configured,
      );
      final settings = (await admitted.settings()).fold(
        (settings) => settings,
        (_) => fail('Configured settings were not admitted'),
      );
      final vault = EncryptedVault(
        id: '11' * 32,
        salt: '22' * 16,
        ciphertext: List.filled(64, 0),
        createdAt: DateTime.utc(2026),
      );
      expect(
        await monitoring.register(settings, vault),
        isA<Ok<void, RecoverBullFailure>>(),
      );
    },
  );

  test(
    'uses the latest timestamp and any verification per backup method',
    () async {
      final database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final usages = database.recoverbullWalletBackups;
      await database.batch((batch) {
        batch.insertAll(usages, [
          RecoverbullWalletBackupsCompanion.insert(
            walletId: 'parent',
            secretFingerprint: const Value('00000001'),
            encryptedVaultTested: true,
            physicalBackupTested: false,
            latestEncryptedBackup: const Value(10),
          ),
          RecoverbullWalletBackupsCompanion.insert(
            walletId: 'child',
            secretFingerprint: const Value('00000001'),
            encryptedVaultTested: false,
            physicalBackupTested: true,
            latestEncryptedBackup: const Value(20),
            latestPhysicalBackup: const Value(15),
          ),
          RecoverbullWalletBackupsCompanion.insert(
            walletId: 'watch-only',
            encryptedVaultTested: false,
            physicalBackupTested: false,
            latestPhysicalBackup: const Value(99),
          ),
        ]);
      });
      expect(await readSecretBackupProjection(database, '00000001'), (
        encryptedVaultTested: true,
        physicalBackupTested: true,
        latestEncryptedBackup: 20,
        latestPhysicalBackup: 15,
      ));
      expect(await readSecretBackupProjection(database, '00000002'), (
        encryptedVaultTested: false,
        physicalBackupTested: false,
        latestEncryptedBackup: null,
        latestPhysicalBackup: null,
      ));
    },
  );
}
