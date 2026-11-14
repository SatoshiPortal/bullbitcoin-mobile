import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show VaultKey;

import '../domain/entities/encrypted_vault.dart';
import '../domain/entities/vault_backup.dart';
import '../domain/entities/vault_context.dart';
import '../domain/entities/vault_recovery.dart';
import '../domain/entities/backup_status.dart';
import '../domain/entities/backup_settings.dart';
import '../domain/entities/vault_completion.dart';
import '../domain/usecases/manage_backup_settings_usecase.dart';
import '../domain/usecases/parse_vault_usecase.dart';
import '../domain/usecases/recover_server_vault_usecase.dart';
import '../domain/usecases/read_backup_status_usecase.dart';
import '../domain/usecases/check_backup_server_usecase.dart';
import '../domain/usecases/start_backup_monitoring_usecase.dart';
import '../domain/recoverbull_failure.dart';
import '../domain/usecases/create_vault_usecase.dart';
import '../domain/usecases/restore_vault_usecase.dart';
import '../domain/usecases/test_vault_usecase.dart';

final class RecoverBullFacade {
  final CreateVaultUsecase _create;
  final TestVaultUsecase _test;
  final RestoreVaultUsecase _restore;
  final ReadBackupStatusUsecase? _status;
  final StartBackupMonitoringUsecase? _coldStart;
  final CheckBackupServerUsecase? _checkServer;
  final ParseVaultUsecase? _parse;
  final ManageBackupSettingsUsecase? _settings;
  final RecoverServerVaultUsecase? _recoverServer;

  @internal
  const RecoverBullFacade(
    this._create,
    this._test,
    this._restore, [
    this._status,
    this._coldStart,
    this._checkServer,
    this._parse,
    this._settings,
    this._recoverServer,
  ]);

  Future<Result<BackupStatus, RecoverBullFailure>> status(
    VaultContext context,
  ) =>
      _status?.execute(context) ??
      Future.value(const Err(RecoverBullJournalFailure()));

  Future<void> checkAtColdStart() async => _coldStart?.execute();

  Future<Result<bool, RecoverBullFailure>> checkServer() =>
      _checkServer?.execute() ??
      Future.value(const Err(RecoverBullJournalFailure()));

  Result<EncryptedVault, RecoverBullFailure> parseVault(String document) =>
      _parse?.execute(document) ?? const Err(VaultInvalidFailure());

  Future<Result<BackupSettings, RecoverBullFailure>> settings() =>
      _settings?.execute(const ReadBackupSettings()) ??
      Future.value(const Err(RecoverBullJournalFailure()));

  Future<Result<BackupSettings, RecoverBullFailure>> acceptServer(
    Uri displayedServer,
  ) =>
      _settings?.execute(AcceptBackupServer(displayedServer)) ??
      Future.value(const Err(RecoverBullJournalFailure()));

  Future<Result<VaultCompletion, RecoverBullFailure>> recoverFromServer({
    required EncryptedVault vault,
    required String password,
    String passphrase = '',
    bool allowUnverified = false,
  }) =>
      _recoverServer?.execute(
        vault: vault,
        password: password,
        passphrase: passphrase,
        allowUnverified: allowUnverified,
      ) ??
      Future.value(const Err(RecoverBullJournalFailure()));

  @visibleForTesting
  Future<Result<VaultBackup, RecoverBullFailure>> create({
    bool passphraseWarningAccepted = false,
  }) => _create.execute(passphraseWarningAccepted: passphraseWarningAccepted);

  @visibleForTesting
  Future<Result<VaultContext, RecoverBullFailure>> test({
    required EncryptedVault vault,
    required VaultKey key,
    String passphrase = '',
  }) => _test.execute(vault: vault, key: key, passphrase: passphrase);

  @visibleForTesting
  Future<Result<VaultRecovery, RecoverBullFailure>> restore({
    required EncryptedVault vault,
    required VaultKey key,
    required BitcoinNetwork network,
    required bool Function() cancelled,
    String passphrase = '',
    bool allowUnverified = false,
  }) => _restore.execute(
    vault: vault,
    key: key,
    network: network,
    cancelled: cancelled,
    passphrase: passphrase,
    allowUnverified: allowUnverified,
  );
}
