import '../entities/decrypted_vault.dart';
import '../entities/recoverbull_network.dart';
import '../recoverbull_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
import '../recoverbull_default_wallets_port.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;

/// If the key server is down
class RestoreVaultUsecase {
  final LogSink log;
  final RecoverBullDefaultWalletsPort _createDefaultWallets;

  RestoreVaultUsecase({
    required this.log,
    required RecoverBullDefaultWalletsPort createDefaultWalletsUsecase,
  }) : _createDefaultWallets = createDefaultWalletsUsecase;

  // Orchestrates the still-throwing wallet core repo; the local try/catch is
  // the boundary, mapping any failure to a sanitized core failure. Returns the
  // network of the restored default wallets.
  Future<Result<RecoverBullNetwork, RecoverBullFailure>> execute({
    required DecryptedVault decryptedVault,
  }) async {
    try {
      final mnemonic = bip39.Mnemonic.fromWords(
        words: decryptedVault.mnemonic,
        language: bip39.Language.english,
        passphrase: '',
      );

      final wallets = await _createDefaultWallets.execute(
        mnemonicWords: mnemonic.words,
      );
      if (wallets.isEmpty) {
        log.error('recoverbull.vault.restore.no_default_wallet');
        return const Err(
          RecoverBullUnexpectedFailure('Vault restoration failed'),
        );
      }

      log.fine('recoverbull.vault.restored');
      return Ok(wallets.first.network);
    } catch (e, st) {
      log.error(
        'recoverbull.vault.restore.failed',
        error: 'Vault restoration failed',
        trace: st,
      );
      return const Err(
        RecoverBullUnexpectedFailure('Vault restoration failed'),
      );
    }
  }
}
