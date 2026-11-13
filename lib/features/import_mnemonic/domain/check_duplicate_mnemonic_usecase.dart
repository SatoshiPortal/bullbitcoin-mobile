import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_mnemonic_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

/// Whether importing these words would duplicate a wallet the app already has.
///
/// A stored secret that no wallet signs with is not a duplicate: the import reuses it (`ImportWalletUsecase`). That is what a reinstall keeping the keystore, or a reset of the local database, leaves behind.
class CheckDuplicateMnemonicUsecase {
  final Secrets _secrets;
  final WalletRepository _wallets;

  CheckDuplicateMnemonicUsecase({
    required this._secrets,
    required WalletRepository walletRepository,
  }) : _wallets = walletRepository;

  @useResult
  Future<Result<void, ImportMnemonicFailure>> execute({
    required List<String> mnemonicWords,
    Language language = Language.english,
    String passphrase = '',
  }) async {
    try {
      // This preflight avoids an unnecessary wallet scan. The strict import
      // remains responsible for rejecting a duplicate at the time of storage.
      return switch (await _secrets.contains(
        words: mnemonicWords,
        language: language,
        passphrase: passphrase,
      )) {
        Ok(value: true) =>
          await _usedByAWallet(mnemonicWords)
              ? const Err(ImportMnemonicDuplicateFailure())
              : const Ok(null),
        Ok() => const Ok(null),
        Err(:final failure) => Err(
          ImportMnemonicUnexpectedFailure(failure.toString()),
        ),
      };
    } catch (e, st) {
      log.severe(
        message: 'Duplicate mnemonic check failed',
        error: e,
        trace: st,
      );
      return Err(ImportMnemonicUnexpectedFailure(e.toString()));
    }
  }

  /// Whether a wallet that signs locally holds a secret with these words. Any doubt counts as yes: a false duplicate only asks the user to look again, a false orphan would let a wallet be imported twice.
  ///
  /// Compares words only, so a wallet holding the same words under another passphrase also counts — the conservative side.
  Future<bool> _usedByAWallet(List<String> words) async {
    final List<Fingerprint?> fingerprints;
    switch (await _wallets.getWallets()) {
      case Ok(:final value):
        fingerprints = [
          for (final wallet in value)
            if (wallet.signsLocally)
              Fingerprint.tryParse(wallet.masterFingerprint),
        ];
      case Err():
        return true;
    }
    for (final fingerprint in fingerprints.toSet()) {
      if (fingerprint == null) return true;
      final Secret secret;
      switch (await _secrets.fetch(fingerprint)) {
        case Ok(:final value):
          secret = value;
        case Err():
          return true;
      }
      switch (await secret.verify.mnemonic(words)) {
        case Ok(value: true):
          return true;
        case Ok():
          break;
        case Err():
          return true;
      }
    }
    return false;
  }
}
