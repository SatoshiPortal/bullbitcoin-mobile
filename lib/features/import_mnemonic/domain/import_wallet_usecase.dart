import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:secrets/secrets.dart';
import 'package:primitives/primitives.dart' show Fingerprint;
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/check_duplicate_mnemonic_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_mnemonic_failure.dart';
import 'package:meta/meta.dart';
import 'package:synchronized/synchronized.dart';

class ImportWalletUsecase {
  /// Imports are serialised process-wide. Two concurrent imports of the same
  /// words each saw "not stored yet", each imported, and the one whose wallet
  /// failed then trashed the seed the other's wallet had just been built on
  /// (Codex, import-race, 2026-09-16). A user cannot start two imports at
  /// once on purpose, so the lock costs nothing and removes the race.
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

      // Package failures come back as values; this usecase already reports every exception as an unexpected failure below, so unwrap by throwing.
      T unwrap<T>(Result<T, SecretFailure> r) => switch (r) {
        Ok(:final value) => value,
        Err(:final failure) => throw StateError(failure.runtimeType.toString()),
      };
      final fingerprint = unwrap(
        await _secrets.idOf(words: mnemonicWords, passphrase: passphrase),
      );
      final seedAlreadyStored = unwrap(await _secrets.exists(fingerprint));
      final secret = unwrap(
        await _secrets.import(words: mnemonicWords, passphrase: passphrase),
      );
      if (!seedAlreadyStored) seedCreatedByThisImport = fingerprint;
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
    } catch (e, st) {
      // Remove the orphaned seed so a later import of the same mnemonic is
      // not rejected as a duplicate (issue #2634). Only a seed this call
      // created is orphaned; a pre-existing one belongs to another wallet.
      // A cleanup failure is logged but must not mask the import error.
      // And even then, never a seed some wallet has come to reference: a
      // lookup that fails keeps the seed, because an orphan in the keystore
      // is recoverable and a stranded wallet is not.
      if (seedCreatedByThisImport != null &&
          !await _referencedByAWallet(seedCreatedByThisImport)) {
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

  Future<bool> _referencedByAWallet(Fingerprint fingerprint) async {
    try {
      final wallets = await _wallet.getWallets();
      // Only a wallet that signs locally holds this seed; a watch-only wallet
      // with the same origin fingerprint does not, whatever its spelling.
      // Same rule as DeleteWalletUsecase and DeleteSecretUsecase.
      return wallets.any(
        (w) =>
            w.signsLocally &&
            Fingerprint.tryParse(w.masterFingerprint) == fingerprint,
      );
    } catch (e) {
      log.warning('Could not check wallet references before cleanup: $e');
      return true;
    }
  }
}
