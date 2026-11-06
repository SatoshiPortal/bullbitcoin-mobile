import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:secrets/secrets.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
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
  final SettingsRepository _settingsRepository;
  final WalletRepository _wallet;

  ImportWalletUsecase({
    required this._checkDuplicateMnemonicUsecase,
    required this._secrets,
    required this._settingsRepository,
    required WalletRepository walletRepository,
  }) : _wallet = walletRepository;

  @useResult
  Future<Result<Wallet, ImportMnemonicFailure>> execute({
    required List<String> mnemonicWords,
    ScriptType scriptType = ScriptType.bip84,
    String passphrase = '',
    String? label,
  }) => _imports.synchronized(
    () => _execute(
      mnemonicWords: mnemonicWords,
      scriptType: scriptType,
      passphrase: passphrase,
      label: label,
    ),
  );

  Future<Result<Wallet, ImportMnemonicFailure>> _execute({
    required List<String> mnemonicWords,
    required ScriptType scriptType,
    required String passphrase,
    required String? label,
  }) async {
    switch (await _checkDuplicateMnemonicUsecase.execute(
      mnemonicWords: mnemonicWords,
      passphrase: passphrase,
    )) {
      case Err(:final failure):
        return Err(failure);
      case Ok():
        break;
    }

    try {
      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;
      final bitcoinNetwork = environment.isMainnet
          ? Network.bitcoinMainnet
          : Network.bitcoinTestnet;

      final Secret secret;
      switch (await _secrets.import(
        words: mnemonicWords,
        passphrase: passphrase,
      )) {
        case Ok(:final value):
          secret = value;
        case Err(failure: SecretAlreadyExistsFailure()):
          // The preflight check is indicative; another operation may have
          // stored this secret since then. A duplicate owns no cleanup.
          return const Err(ImportMnemonicDuplicateFailure());
        case Err(:final failure):
          return Err(ImportMnemonicUnexpectedFailure(failure.toString()));
      }
      final wallet = await _wallet.createWallet(
        secret: secret,
        network: bitcoinNetwork,
        scriptType: scriptType,
        isDefault: false,
        sync: false,
        label: label,
      );

      log.fine('Wallet imported');

      return Ok(wallet);
    } catch (e) {
      // Provisioning may already have committed a catalog row. Preserve custody;
      // orphan cleanup is an explicit user action, never failure compensation.
      log.severe(
        message: 'Import wallet failed',
        error: e.runtimeType,
        trace: StackTrace.empty,
      );
      return Err(ImportMnemonicUnexpectedFailure(e.toString()));
    }
  }
}
