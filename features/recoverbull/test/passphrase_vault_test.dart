import 'dart:convert';

import 'package:bull_recoverbull/src/data/secrets_vault_repository.dart';
import 'package:bull_recoverbull/src/domain/entities/backup_settings.dart';
import 'package:bull_recoverbull/src/domain/entities/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/entities/vault_backup.dart';
import 'package:bull_recoverbull/src/domain/entities/vault_context.dart';
import 'package:bull_recoverbull/src/domain/entities/vault_recovery.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_wallet_port.dart';
import 'package:bull_recoverbull/src/domain/repositories/attempt_monitoring_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/backup_metadata_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/vault_repository.dart';
import 'package:bull_recoverbull/src/domain/usecases/complete_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/create_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/restore_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/test_vault_usecase.dart';
import 'package:bull_recoverbull/src/public/recoverbull_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:convert/convert.dart' as convert;
import 'package:recoverbull/recoverbull.dart';
import 'package:secrets/secrets.dart' as custody;
import 'package:secrets/testing.dart';

class _Wallets implements RecoverBullWalletPort {
  VaultContext? current;
  int restores = 0;

  _Wallets(this.current);

  @override
  Future<Result<VaultContext?, RecoverBullFailure>> currentDefault() async =>
      Ok(current);

  @override
  Future<Result<VaultContext, RecoverBullFailure>> restoreDefaults(
    VaultContext requested,
  ) async {
    restores++;
    return Ok(requested);
  }
}

class _Metadata implements BackupMetadataRepository {
  int verified = 0;
  final BackupSettings current;
  _Metadata(this.current);

  @override
  Future<Result<BackupSettings, RecoverBullFailure>> settings() async =>
      Ok(current);
  @override
  Future<Result<void, RecoverBullFailure>> markVerified(
    VaultContext context,
    EncryptedVault vault,
  ) async {
    verified++;
    return const Ok(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Monitoring implements AttemptMonitoringRepository {
  int registrations = 0;
  @override
  Future<Result<void, RecoverBullFailure>> register(
    BackupSettings settings,
    EncryptedVault vault,
  ) async {
    registrations++;
    return const Ok(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Vaults implements VaultRepository {
  final VaultBackup backup;
  int creates = 0;
  _Vaults(this.backup);
  @override
  Future<Result<VaultBackup, RecoverBullFailure>> create(
    VaultContext context,
  ) async {
    creates++;
    return Ok(backup);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

T ok<T>(Result<T, RecoverBullFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => fail('unexpected failure: ${failure.runtimeType}'),
};

void main() {
  const passphrase = 'synthetic-passphrase';
  final words = [...List.filled(11, 'abandon'), 'about'];
  late FakeSecureStoragePlatform storage;
  late custody.Secrets secrets;
  late custody.Secret secret;
  late SecretsVaultRepository repository;
  late VaultContext context;
  late VaultBackup backup;

  setUp(() async {
    storage = FakeSecureStoragePlatform().install();
    secrets = custody.Secrets(scratchDirectory: () async => '.');
    final imported = await secrets.import(words: words, passphrase: passphrase);
    secret = switch (imported) {
      Ok(:final value) => value,
      Err(:final failure) => fail('import failed: ${failure.runtimeType}'),
    };
    context = VaultContext(
      fingerprint: secret.id,
      network: BitcoinNetwork.mainnet,
      hasPassphrase: true,
    );
    repository = SecretsVaultRepository(secrets);
    backup = ok(await repository.create(context));
  });

  test('a protected default does not put its passphrase in the vault', () {
    final plaintext =
        jsonDecode(
              utf8.decode(
                RecoverBull.restoreBackup(
                  backup: BullBackup.fromJson(repository.encode(backup.vault)),
                  backupKey: convert.hex.decode(backup.key.hex),
                ),
              ),
            )
            as Map<String, dynamic>;
    expect(
      plaintext.keys,
      unorderedEquals([
        'masterFingerprint',
        'isEncryptedVaultTested',
        'latestEncryptedBackup',
        'mnemonic',
        'mnemonicLanguage',
      ]),
    );
    expect(plaintext['mnemonic'], words);
    expect(plaintext['mnemonicLanguage'], 'english');
    expect(jsonEncode(plaintext), isNot(contains(passphrase)));
  });

  test(
    'inspection requires the passphrase and makes no keystore writes',
    () async {
      final before = Map<String, String>.of(storage.entries);
      storage.scriptedWrites.add(Exception('unexpected write'));
      expect(
        (await repository.fingerprint(backup.vault, backup.key) as Err).failure,
        isA<VaultPassphraseRequiredFailure>(),
      );
      expect(
        (await repository.fingerprint(
                  backup.vault,
                  backup.key,
                  passphrase: 'wrong',
                )
                as Err)
            .failure,
        isA<VaultPassphraseRequiredFailure>(),
      );
      expect(
        ok(
          await repository.fingerprint(
            backup.vault,
            backup.key,
            passphrase: passphrase,
          ),
        ),
        secret.id,
      );
      expect(storage.entries, before);
      expect(storage.scriptedWrites, hasLength(1));
    },
  );

  test(
    'a wrong restore cannot write; the correct passphrase restores the original',
    () async {
      storage.entries.clear();
      storage.scriptedWrites.add(Exception('unexpected write'));
      expect(
        (await repository.restore(backup.vault, backup.key, passphrase: 'wrong')
                as Err)
            .failure,
        isA<VaultPassphraseRequiredFailure>(),
      );
      expect(storage.entries, isEmpty);
      expect(storage.scriptedWrites, hasLength(1));
      storage.scriptedWrites.clear();
      expect(
        ok(
          await repository.restore(
            backup.vault,
            backup.key,
            passphrase: passphrase,
          ),
        ),
        secret.id,
      );
      expect(storage.entries, isNotEmpty);
    },
  );

  test(
    'unverified recovery permits only the empty-passphrase sibling',
    () async {
      storage.entries.clear();
      storage.scriptedWrites.add(Exception('unexpected write'));
      expect(
        (await repository.restore(
                  backup.vault,
                  backup.key,
                  passphrase: 'wrong',
                  allowUnverified: true,
                )
                as Err)
            .failure,
        isA<VaultPassphraseRequiredFailure>(),
      );
      expect(storage.entries, isEmpty);
      expect(storage.scriptedWrites, hasLength(1));
      storage.scriptedWrites.clear();
      final sibling = ok(
        await repository.restore(
          backup.vault,
          backup.key,
          allowUnverified: true,
        ),
      );
      expect(sibling, isNot(secret.id));
      final plain = await secrets.import(words: words);
      expect((plain as Err).failure, isA<custody.SecretAlreadyExistsFailure>());
      expect(
        ((plain as Err).failure as custody.SecretAlreadyExistsFailure).id,
        sibling,
      );
    },
  );

  test('creation requires explicit acknowledgement before sealing', () async {
    final wallets = _Wallets(context);
    final vaults = _Vaults(backup);
    final create = CreateVaultUsecase(vaults, wallets);
    final result = await create.execute();
    expect(
      (result as Err).failure,
      isA<VaultPassphraseAcknowledgementFailure>(),
    );
    expect(vaults.creates, 0);
    expect(
      ok(
        await create.execute(passphraseWarningAccepted: true),
      ).context.fingerprint,
      secret.id,
    );
    expect(vaults.creates, 1);
  });

  test('facade forwards passphrase to inspection and restoration', () async {
    final wallets = _Wallets(context);
    final facade = RecoverBullFacade(
      CreateVaultUsecase(repository, wallets),
      TestVaultUsecase(repository, wallets),
      RestoreVaultUsecase(repository, wallets),
    );
    expect(
      (await facade.test(vault: backup.vault, key: backup.key) as Err).failure,
      isA<VaultPassphraseRequiredFailure>(),
    );
    expect(
      ok(
        await facade.test(
          vault: backup.vault,
          key: backup.key,
          passphrase: passphrase,
        ),
      ).fingerprint,
      secret.id,
    );
    final restored = ok(
      await facade.restore(
        vault: backup.vault,
        key: backup.key,
        network: BitcoinNetwork.mainnet,
        cancelled: () => false,
        passphrase: passphrase,
      ),
    );
    expect(restored, isA<VaultRecovered>());
    expect(restored.importedSecret, secret.id);
    expect(wallets.restores, 1);
  });

  test('unverified recovery never marks the backup verified', () async {
    storage.entries.clear();
    final wallets = _Wallets(context);
    final monitoring = _Monitoring();
    final settings = BackupSettings(
      server: Uri.parse('http://example.onion'),
      permissionGranted: true,
      monitoringEnabled: false,
      generation: 0,
    );
    final metadata = _Metadata(settings);
    final complete = CompleteVaultUsecase(
      TestVaultUsecase(repository, wallets),
      RestoreVaultUsecase(repository, wallets),
      metadata,
      monitoring,
    );
    final result = ok(
      await complete.execute(
        vault: backup.vault,
        key: backup.key,
        recoveryNetwork: BitcoinNetwork.mainnet,
        cancelled: () => false,
        allowUnverified: true,
        capturedSettings: settings,
      ),
    );
    expect(result.recovery, isA<VaultRecovered>());
    expect(result.verifiedContext, isNull);
    expect(metadata.verified, 0);
    expect(monitoring.registrations, 1);
  });
}
