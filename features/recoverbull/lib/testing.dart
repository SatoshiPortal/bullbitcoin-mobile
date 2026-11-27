import 'dart:io';

import 'package:drift/native.dart';

import 'package:bull_tor/tor.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show Secrets, VaultKey;

import 'src/data/database/recoverbull_cutover.dart';
import 'src/data/database/recoverbull_database.dart';
import 'src/data/database/recoverbull_storage.dart';
import 'src/data/key_server_repository_impl.dart';
import 'src/domain/entities/encrypted_vault.dart';
import 'src/domain/recoverbull_environment_port.dart';
import 'src/domain/recoverbull_failure.dart';
import 'src/domain/recoverbull_permission_port.dart';
import 'src/domain/recoverbull_route_port.dart';
import 'src/domain/recoverbull_wallet_port.dart';
import 'src/domain/usecases/manage_backup_settings_usecase.dart';
import 'src/public/recoverbull_runtime.dart';

export 'src/data/database/recoverbull_wallet_backups.dart'
    show writeWalletBackupForTesting, removeWalletBackupForTesting;

/// Composes an isolated runtime for integration tests without changing the
/// production server selection or transport policy.
Future<RecoverBullRuntime> openRecoverBullRuntimeForTesting({
  required String databasePath,
  required Secrets secrets,
  required RecoverBullWalletPort wallets,
  required RecoverBullEnvironmentPort environment,
  required RecoverBullPermissionPort permission,
  required RecoverBullRoutePort routes,
}) => RecoverBullRuntime.openWithStorage(
  storage: recoverBullStorageForTesting(databasePath),
  secrets: secrets,
  wallets: wallets,
  environment: environment,
  permission: permission,
  routes: routes,
  clients: const TorHttpClientFactory(),
  server: Uri.parse('http://fixture.onion'),
);

Future<Result<void, RecoverBullFailure>> acceptRecoverBullServerForTesting(
  RecoverBullRuntime runtime,
) async => (await runtime.settings.execute(
  AcceptBackupServer(Uri.parse('http://fixture.onion')),
)).map<void>((_) {});

/// Seeds only an ephemeral IPv4 loopback server using the real client.
Future<Result<void, RecoverBullFailure>> seedRecoverBullServerForTesting({
  required int port,
  required EncryptedVault vault,
  required String password,
  required VaultKey key,
}) async {
  final repository = KeyServerRepositoryImpl(
    server: Uri(scheme: 'http', host: '127.0.0.1', port: port),
    transport: HttpClient(),
    releaseRoute: () async {},
    operationTimeout: const Duration(minutes: 1),
  );
  try {
    return await repository.store(vault, password, key);
  } finally {
    await repository.close();
  }
}

RecoverBullDatabase openRecoverBullDatabaseForTesting(String path) =>
    RecoverBullDatabase.forTesting(
      NativeDatabase.createInBackground(
        File(path),
        setup: (database) {
          final version =
              database.select('PRAGMA user_version').single['user_version']
                  as int;
          if (version > RecoverBullDatabase.schema) {
            throw const RecoverBullUnsupportedSchemaException();
          }
          database.execute('PRAGMA busy_timeout = 2000');
          database.execute('PRAGMA journal_mode = WAL');
          database.execute('PRAGMA synchronous = FULL');
          database.execute('PRAGMA secure_delete = ON');
        },
      ),
    );

RecoverBullStorage recoverBullStorageForTesting(String path) =>
    RecoverBullStorage.forTesting(() async {
      final database = openRecoverBullDatabaseForTesting(path);
      try {
        await database.forceOpen();
        return database;
      } catch (_) {
        await database.close();
        rethrow;
      }
    });

RecoverBullCutover recoverBullCutoverForTesting({
  required File file,
  required File standalone,
  bool regtest = false,
}) {
  final path = file.path;
  return RecoverBullCutover.withTestExecutor(
    file: file,
    standalone: standalone,
    regtest: regtest,
    executor: () => NativeDatabase(File(path)),
  );
}
