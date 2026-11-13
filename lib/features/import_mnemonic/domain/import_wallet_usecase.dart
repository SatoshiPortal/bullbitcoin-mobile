import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:secrets/secrets.dart';
import 'package:primitives/primitives.dart' show Err, Fingerprint, Ok, Result;
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/check_duplicate_mnemonic_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_mnemonic_failure.dart';
import 'package:meta/meta.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_mutation_guard.dart';
import 'package:bb_mobile/core/wallet/domain/ports/wallet_retention_port.dart';

class ImportWalletUsecase {
  final CheckDuplicateMnemonicUsecase _checkDuplicateMnemonicUsecase;
  final Secrets _secrets;
  final SettingsRepository _settingsRepository;
  final WalletRepository _wallet;
  final WalletMutationGuard _mutationGuard;
  final WalletRetentionPort _retention;

  ImportWalletUsecase({
    required this._checkDuplicateMnemonicUsecase,
    required this._secrets,
    required this._settingsRepository,
    required WalletRepository walletRepository,
    required this._mutationGuard,
    required this._retention,
  }) : _wallet = walletRepository;

  @useResult
  Future<Result<Wallet, ImportMnemonicFailure>> execute({
    required List<String> mnemonicWords,
    Language language = Language.english,
    ScriptType scriptType = ScriptType.bip84,
    String passphrase = '',
    String? label,
  }) => _mutationGuard.exclusive(
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
      // And even then, never a seed some wallet has come to reference: a
      // lookup that fails keeps the seed, because an orphan in the keystore
      // is recoverable and a stranded wallet is not.
      if (seedCreatedByThisImport != null &&
          !await _referencedByAWallet(seedCreatedByThisImport) &&
          !await _isRetained(seedCreatedByThisImport)) {
        final deletion = await _secrets.trash(seedCreatedByThisImport);
        if (deletion case Err(:final failure)) {
          log.warning(
            'Failed to clean up orphaned seed after import failure',
            error: failure,
          );
        }
      }
      log.severe(message: 'Import wallet failed', error: e, trace: st);
      return Err(ImportMnemonicUnexpectedFailure(e.toString()));
    }
  }

  Future<bool> _isRetained(Fingerprint fingerprint) async {
    try {
      return await _retention.retainsSecret(fingerprint);
    } catch (_) {
      log.warning('Could not check secret retention during import cleanup');
      return true;
    }
  }

  Future<bool> _referencedByAWallet(Fingerprint fingerprint) async {
    try {
      switch (await _wallet.getWallets()) {
        // Only a wallet that signs locally holds this seed; a watch-only
        // wallet with the same origin fingerprint does not, whatever its
        // spelling. Same rule as DeleteWalletUsecase and DeleteSecretUsecase.
        case Ok(value: final wallets):
          return wallets.any(
            (w) =>
                w.signsLocally &&
                Fingerprint.tryParse(w.masterFingerprint) == fingerprint,
          );
        case Err(:final failure):
          // Unknown counts as referenced: cleanup must never delete a seed a
          // wallet may still use.
          log.warning(
            'Could not check wallet references before cleanup: '
            '${failure.logMessage}',
          );
          return true;
      }
    } catch (e) {
      log.warning('Could not check wallet references before cleanup: $e');
      return true;
    }
  }
}
