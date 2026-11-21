import 'package:preferences/preferences.dart' hide Language;
import 'package:secrets/secrets.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result, ScriptType;
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/check_duplicate_mnemonic_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_mnemonic_failure.dart';
import 'package:meta/meta.dart';
import 'package:synchronized/synchronized.dart';

class ImportWalletUsecase {
  /// Imports are serialised process-wide so catalog provisioning completes
  /// before another wallet import uses the same secret.
  static final _imports = Lock();

  final CheckDuplicateMnemonicUsecase _checkDuplicateMnemonicUsecase;
  final Secrets _secrets;
  final Preferences _settingsRepository;
  final WalletRepository _wallet;
  final ParentCustodyAdmissionPort _admission;

  ImportWalletUsecase({
    required this._checkDuplicateMnemonicUsecase,
    required this._secrets,
    required this._settingsRepository,
    required WalletRepository walletRepository,
    required this._admission,
  }) : _wallet = walletRepository;

  @useResult
  Future<Result<Wallet, ImportMnemonicFailure>> execute({
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

  Future<Result<Wallet, ImportMnemonicFailure>> _execute({
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
      final settings = (await _settingsRepository.fetch()).fold(
        (value) => value,
        (failure) => throw Exception('Preferences read failed'),
      );
      final bitcoinNetwork = Network.fromEnvironment(
        environment: settings.environment.networkEnv,
        isLiquid: false,
      );
      if (bitcoinNetwork == Network.bitcoinRegtest &&
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
          if (await _checkDuplicateMnemonicUsecase.isReferenced(
            id,
            bitcoinNetwork,
          )) {
            log.warning('Wallet import refused reason=duplicate');
            return const Err(ImportMnemonicDuplicateFailure());
          }
          switch (await _secrets.fetch(id)) {
            case Ok(:final value):
              secret = value;
            case Err(:final failure):
              return Err(ImportMnemonicUnexpectedFailure(failure.toString()));
          }
          log.warning('Resuming orphan mnemonic import');
        case Err(:final failure):
          return Err(ImportMnemonicUnexpectedFailure(failure.toString()));
      }
      final Wallet wallet;
      switch (await _wallet.importWallet(
        parent: secret.id,
        secrets: _secrets,
        admission: _admission,
        network: bitcoinNetwork,
        scriptType: scriptType,
        label: label,
      )) {
        case Ok(:final value):
          wallet = value;
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

      return Ok(wallet);
    } catch (e) {
      // Provisioning may already have committed a catalog row. Preserve custody;
      // orphan cleanup is an explicit user action, never failure compensation.
      log.severe(
        message: 'Import wallet failed',
        error: 'storage',
        trace: StackTrace.empty,
      );
      return Err(ImportMnemonicUnexpectedFailure(e.toString()));
    }
  }
}
