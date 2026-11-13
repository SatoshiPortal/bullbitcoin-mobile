import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:secrets/secrets.dart';
import 'package:primitives/primitives.dart' show Err, Fingerprint, Ok, Result;
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/check_duplicate_mnemonic_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_mnemonic_failure.dart';
import 'package:meta/meta.dart';
import 'package:synchronized/synchronized.dart';

class ImportWalletUsecase {
  /// Imports are serialised process-wide so wallet creation and any cleanup
  /// complete before another wallet import uses the same secret.
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
    Language language = Language.english,
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

    // Set only once this import has actually stored a NEW seed. The cleanup
    // below must never touch a seed that already existed: it is shared by
    // whatever wallet was imported from the same mnemonic before, and
    // deleting it would strand that wallet's funds.
    Fingerprint? seedCreatedByThisImport;

    try {
      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;
      final bitcoinNetwork = environment.isMainnet
          ? Network.bitcoinMainnet
          : Network.bitcoinTestnet;

      final Secret secret;
      switch (await _secrets.import(
        words: mnemonicWords,
        language: language,
        passphrase: passphrase,
      )) {
        case Ok(:final value):
          secret = value;
          seedCreatedByThisImport = secret.id;
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

      log.fine(
        'Wallet imported language=${language.name} network=${bitcoinNetwork.name} script=${scriptType.name}',
      );

      return Ok(wallet);
    } catch (e, st) {
      // Remove the orphaned seed so a later import of the same mnemonic is
      // not rejected as a duplicate (issue #2634). Only a seed this call
      // created is orphaned; a pre-existing one belongs to another wallet.
      // A cleanup failure is logged but must not mask the import error.
      if (seedCreatedByThisImport != null) {
        await _deleteOrphanedSeed(seedCreatedByThisImport);
      }
      if (e is WalletAlreadyExistsException) {
        return const Err(ImportMnemonicDuplicateFailure());
      }
      log.severe(message: 'Import wallet failed', error: e, trace: st);
      return Err(ImportMnemonicUnexpectedFailure(e.toString()));
    }
  }

  Future<void> _deleteOrphanedSeed(Fingerprint fingerprint) async {
    // A failed wallet lookup cannot establish that a secret is unused.
    try {
      switch (await _wallet.getWallets()) {
        case Ok(:final value):
          if (value.any(
            (wallet) => wallet.localSeedFingerprints.contains(fingerprint.hex),
          )) {
            return;
          }
        case Err():
          return;
      }
    } catch (e) {
      log.warning('Could not check wallet references before cleanup: $e');
      return;
    }
    final deletion = await _secrets.trash(fingerprint);
    if (deletion case Err(:final failure)) {
      log.warning(
        'Failed to clean up orphaned seed after import failure',
        error: failure,
      );
    }
  }
}
