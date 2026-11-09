import 'dart:async';

import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/src/data/attempt_monitoring_repository_impl.dart';
import 'package:bull_recoverbull/src/data/backup_metadata_repository_impl.dart';
import 'package:bull_recoverbull/src/data/database/recoverbull_database.dart';
import 'package:bull_recoverbull/src/data/secrets_vault_repository.dart';
import 'package:bull_recoverbull/src/domain/entities/vault_key_fetch.dart';
import 'package:bull_recoverbull/src/domain/entities/vault_provider.dart';
import 'package:bull_recoverbull/src/domain/repositories/google_drive_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/key_server_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/key_server_session_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/vault_file_repository.dart';
import 'package:bull_recoverbull/src/domain/usecases/complete_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/create_and_store_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/create_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/fetch_vault_key_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/manage_vault_session_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/open_key_server_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/restore_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/save_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/test_vault_usecase.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show Failure;
import 'package:secrets/secrets.dart' as custody;
import 'package:secrets/testing.dart';

void main() {
  final context = VaultContext(
    fingerprint: Fingerprint('73c5da0a'),
    network: BitcoinNetwork.testnet,
  );
  late RecoverBullDatabase database;
  late BackupMetadataRepositoryImpl metadata;
  late AttemptMonitoringRepositoryImpl monitoring;
  late SecretsVaultRepository vaults;
  late _Wallets wallets;
  late _Files files;
  late _Server server;
  late BackupSettings settings;
  late CreateAndStoreVaultUsecase create;
  late CompleteVaultUsecase complete;

  setUp(() async {
    FakeSecureStoragePlatform().install();
    final secrets = custody.Secrets(scratchDirectory: () async => '.');
    // Published BIP39 test vector.
    ok(await secrets.import(words: '${'abandon ' * 11}about'.split(' ')));
    vaults = SecretsVaultRepository(secrets);
    wallets = _Wallets(context);
    files = _Files();
    server = _Server();
    database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
    await database.forceOpen();
    metadata = BackupMetadataRepositoryImpl(database);
    monitoring = AttemptMonitoringRepositoryImpl(database, durable: true);
    settings = ok(await metadata.settings());
    ok(await metadata.acceptServer(settings.server));
    settings = ok(await metadata.settings());
    create = CreateAndStoreVaultUsecase(
      CreateVaultUsecase(vaults, wallets),
      SaveVaultUsecase(files, _Drive()),
      metadata,
      monitoring,
      FetchVaultKeyUsecase(monitoring),
    );
    complete = CompleteVaultUsecase(
      TestVaultUsecase(vaults, wallets),
      RestoreVaultUsecase(vaults, wallets),
      metadata,
      monitoring,
    );
  });
  tearDown(() => database.close());

  Future<Result<VaultCompletion, RecoverBullFailure>> save() => create.execute(
    settings: settings,
    server: server,
    provider: VaultProvider.customLocation,
    password: 'public test password',
  );

  test('close during store cleans up through the durable journal', () async {
    server.pendingStore = Completer();
    final saving = save();
    await server.started.future;
    create.close();
    server.pendingStore?.complete(const Ok(null));
    expect(await saving, isA<Err<VaultCompletion, RecoverBullFailure>>());
    expect(server.trashed, 1);
    expect(files.calls, 0);
  });

  test('failed cleanup admission retains the server key', () async {
    server.pendingStore = Completer();
    final saving = save();
    await server.started.future;
    await database.customStatement(
      "CREATE TRIGGER reject_journal BEFORE INSERT ON recoverbull_own_operations BEGIN SELECT RAISE(FAIL, 'test write failure'); END",
    );
    create.close();
    server.pendingStore?.complete(const Ok(null));
    await saving;
    expect(server.trashed, 0);
  });

  for (final succeeds in [true, false]) {
    test(
      'close during provider save preserves its real result: $succeeds',
      () async {
        final saving = save();
        await files.started.future;
        create.close();
        files.pending.complete(
          succeeds ? const Ok(null) : const Err(VaultCancelledFailure()),
        );
        final result = await saving;
        expect(result is Ok, succeeds);
        expect(server.trashed, 0);
        final status = ok(await metadata.status(context));
        expect(status.storedAt != null, succeeds);
        expect(status.isVerified, isFalse);
      },
    );
  }

  test(
    'manual recovery succeeds with an unreadable metadata database',
    () async {
      final backup = ok(await vaults.create(context));
      await database.customStatement('DROP TABLE recoverbull_state');
      final result = ok(
        await complete.execute(
          vault: backup.vault,
          key: backup.key,
          recoveryNetwork: context.network,
          cancelled: () => false,
        ),
      );
      expect(result.recovery, isA<VaultRecovered>());
      expect(result.warning, isNotNull);
      expect(wallets.restores, 1);
      expect(server.trashed, 0);
    },
  );

  test(
    'manual recovery exists even when no metadata connection opened',
    () async {
      final backup = ok(await vaults.create(context));
      final manual = CompleteVaultUsecase(
        TestVaultUsecase(vaults, wallets),
        RestoreVaultUsecase(vaults, wallets),
        null,
        null,
        unavailableFailure: const VaultStorageFailure(),
      );
      final result = ok(
        await manual.execute(
          vault: backup.vault,
          key: backup.key,
          recoveryNetwork: context.network,
          cancelled: () => false,
        ),
      );
      expect(result.recovery, isA<VaultRecovered>());
      expect(result.warning, isA<VaultStorageFailure>());
    },
  );

  test('completed test certifies only its actual context', () async {
    final backup = ok(await vaults.create(context));
    final result = ok(
      await complete.execute(
        vault: backup.vault,
        key: backup.key,
        recoveryNetwork: null,
        cancelled: () => false,
      ),
    );
    expect(result.warning, isNull);
    expect(ok(await metadata.status(context)).isVerified, isTrue);
    expect(
      ok(
        await metadata.status(
          VaultContext(
            fingerprint: context.fingerprint,
            network: BitcoinNetwork.mainnet,
          ),
        ),
      ).isVerified,
      isFalse,
    );
    expect(wallets.restores, 0);
  });

  test(
    'closing a pending fetch prevents import and waits to close its route',
    () async {
      final backup = ok(await vaults.create(context));
      final sessions = _Sessions(server);
      final flow = ManageVaultSessionUsecase(
        metadata,
        OpenKeyServerUsecase(metadata, sessions),
        FetchVaultKeyUsecase(monitoring),
        create,
        complete,
      );
      expect(sessions.opens, 0, reason: 'construction must remain idle');
      final fetching = flow.verify(
        vault: backup.vault,
        password: 'test password',
        recoveryNetwork: context.network,
      );
      await server.fetchStarted.future;
      final closing = flow.close();
      expect(server.closes, 0);
      server.pendingFetch.complete(Ok(VaultKeyFetch(backup.key, null)));
      expect(await fetching, isA<Err<VaultCompletion, RecoverBullFailure>>());
      await closing;
      await flow.close();
      expect(wallets.restores, 0);
      expect(server.closes, 1);
      expect(ok(await metadata.status(context)).isVerified, isFalse);
    },
  );
}

T ok<T, F extends Failure>(Result<T, F> result) => (result as Ok<T, F>).value;

final class _Wallets implements RecoverBullWalletPort {
  final VaultContext context;
  int restores = 0;
  _Wallets(this.context);
  @override
  Future<Result<VaultContext?, RecoverBullFailure>> currentDefault() async =>
      Ok(context);
  @override
  Future<Result<VaultContext, RecoverBullFailure>> restoreDefaults(
    VaultContext requested,
  ) async {
    restores++;
    return Ok(requested);
  }
}

final class _Files extends Fake implements VaultFileRepository {
  int calls = 0;
  final started = Completer<void>();
  final pending = Completer<Result<void, RecoverBullFailure>>();
  @override
  Future<Result<void, RecoverBullFailure>> save(EncryptedVault vault) {
    calls++;
    started.complete();
    return pending.future;
  }
}

final class _Drive extends Fake implements GoogleDriveRepository {}

final class _Server extends Fake implements KeyServerRepository {
  final started = Completer<void>();
  Completer<Result<void, RecoverBullFailure>>? pendingStore;
  int trashed = 0;
  int closes = 0;
  final fetchStarted = Completer<void>();
  final pendingFetch = Completer<Result<VaultKeyFetch, RecoverBullFailure>>();
  @override
  Future<void> close() async {
    closes++;
  }

  @override
  Future<Result<VaultKeyFetch, RecoverBullFailure>> fetch(
    EncryptedVault vault,
    String password,
  ) {
    fetchStarted.complete();
    return pendingFetch.future;
  }

  @override
  Future<Result<void, RecoverBullFailure>> store(
    EncryptedVault vault,
    String password,
    VaultKey key,
  ) {
    started.complete();
    return pendingStore?.future ?? Future.value(const Ok(null));
  }

  @override
  Future<Result<VaultKeyFetch, RecoverBullFailure>> trash(
    EncryptedVault vault,
    String password,
  ) async {
    trashed++;
    return Ok(VaultKeyFetch(VaultKey('11' * 32), null));
  }
}

final class _Sessions implements KeyServerSessionRepository {
  final _Server server;
  int opens = 0;
  _Sessions(this.server);
  @override
  Future<Result<KeyServerRepository, RecoverBullFailure>> open(
    Uri server, {
    bool restartEmbedded = false,
  }) async {
    opens++;
    return Ok(this.server);
  }
}
