import 'package:preferences/preferences.dart' hide Language;
import 'package:provisioning/provisioning.dart'
    show WalletProvisioningBackupRequiredFailure, WalletProvisioningException;
import 'package:secrets/secrets.dart';
import 'package:primitives/primitives.dart'
    show BitcoinNetwork, Err, NetworkEnv, Ok, Result, ScriptType;
import 'package:bull_logger/bull_logger.dart';
import 'package:wallet_import/src/domain/import_operations.dart';
import 'package:wallet_import/src/domain/mnemonic/check_duplicate_mnemonic_usecase.dart';
import 'package:wallet_import/src/domain/import_failure.dart';
import 'package:meta/meta.dart';
import 'package:synchronized/synchronized.dart';

class ImportWalletUsecase {
  /// Imports are serialised process-wide so catalog provisioning completes
  /// before another wallet import uses the same secret.
  static final _imports = Lock();

  final CheckDuplicateMnemonicUsecase _checkDuplicateMnemonicUsecase;
  final Secrets _secrets;
  final Preferences _settingsRepository;
  final ProvisionMnemonicWallet _provision;
  final ParentCustodyAdmissionPort _admission;

  ImportWalletUsecase({
    required this._checkDuplicateMnemonicUsecase,
    required this._secrets,
    required this._settingsRepository,
    required this._provision,
    required this._admission,
  });

  @useResult
  Future<Result<void, ImportMnemonicFailure>> execute({
    required List<String> mnemonicWords,
    required Language language,
    ScriptType scriptType = ScriptType.bip84,
    String passphrase = '',
    String? label,
  }) => _imports.synchronized(
    () => _execute(
      mnemonicWords: mnemonicWords,
      language: language,
      scriptType: scriptType,
      passphrase: passphrase,
      label: label,
    ),
  );

  Future<Result<void, ImportMnemonicFailure>> _execute({
    required List<String> mnemonicWords,
    required Language language,
    required ScriptType scriptType,
    required String passphrase,
    required String? label,
  }) async {
    switch (await _checkDuplicateMnemonicUsecase.execute(
      mnemonicWords: mnemonicWords,
      language: language,
      passphrase: passphrase,
    )) {
      case Err(:final failure):
        log.warning(
          'Wallet import refused reason=${failure is ImportMnemonicDuplicateFailure ? 'duplicate' : 'preflight'}',
        );
        return Err(failure);
      case Ok():
        break;
    }

    try {
      final settings = await _settingsRepository.fetch();
      if (settings is! Ok<SettingsEntity, PreferencesFailure>) {
        return const Err(
          ImportMnemonicUnexpectedFailure('Preferences unavailable'),
        );
      }
      final environment = settings.value.environment.networkEnv;
      if (environment == NetworkEnv.signet) {
        return const Err(
          ImportMnemonicUnexpectedFailure('Unsupported network'),
        );
      }
      final bitcoinNetwork = BitcoinNetwork.values.byName(environment.name);
      if (bitcoinNetwork == BitcoinNetwork.regtest &&
          scriptType != ScriptType.bip84) {
        log.warning('Wallet import refused reason=unsupported');
        return const Err(
          ImportMnemonicUnexpectedFailure('unsupported regtest script'),
        );
      }

      final Secret secret;
      switch (await _secrets.import(
        words: mnemonicWords,
        language: language,
        passphrase: passphrase,
      )) {
        case Ok(:final value):
          secret = value;
        case Err(failure: SecretAlreadyExistsFailure(:final id)):
          switch (await _checkDuplicateMnemonicUsecase.isReferenced(
            id,
            bitcoinNetwork,
          )) {
            case Err(:final failure):
              return Err(failure);
            case Ok(value: true):
              log.warning('Wallet import refused reason=duplicate');
              return const Err(ImportMnemonicDuplicateFailure());
            case Ok(value: false):
              break;
          }
          switch (await _secrets.fetch(id)) {
            case Ok(:final value):
              secret = value;
            case Err(:final failure):
              return Err(
                ImportMnemonicUnexpectedFailure(failure.runtimeType.toString()),
              );
          }
          log.warning('Resuming orphan mnemonic import');
        case Err(:final failure):
          return Err(
            ImportMnemonicUnexpectedFailure(failure.runtimeType.toString()),
          );
      }
      switch (await _provision(
        parent: secret.id,
        secrets: _secrets,
        admission: _admission,
        network: bitcoinNetwork,
        scriptType: scriptType,
        label: label,
      )) {
        case Ok():
          break;
        case Err(failure: ParentCustodyMetadataFailure()):
          log.warning('Wallet import refused reason=custody_metadata');
          return const Err(ImportMnemonicCustodyMetadataFailure());
        case Err():
          log.warning('Wallet import refused reason=custody_unavailable');
          return const Err(
            ImportMnemonicUnexpectedFailure('custody unavailable'),
          );
      }

      log.fine(
        'Wallet imported language=${language.name} network=${bitcoinNetwork.name} script=${scriptType.name}',
      );

      return const Ok(null);
    } on WalletProvisioningException catch (e) {
      // Provisioning refused before publishing the catalog row; the stored
      // words stay for a later import, which resumes them.
      if (e.failure is WalletProvisioningBackupRequiredFailure) {
        log.warning('Wallet import refused reason=backup_required');
        return const Err(ImportMnemonicBackupRequiredFailure());
      }
      return Err(
        ImportMnemonicUnexpectedFailure(e.failure.runtimeType.toString()),
      );
    } on Exception catch (e) {
      // Provisioning may already have committed a catalog row. Preserve custody;
      // orphan cleanup is an explicit user action, never failure compensation.
      log.severe(
        message: 'Import wallet failed',
        error: 'storage',
        trace: StackTrace.empty,
      );
      return Err(ImportMnemonicUnexpectedFailure(e.runtimeType.toString()));
    }
  }
}
