import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_birthday_checkpoint.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;

/// If the key server is down
class RestoreVaultUsecase {
  final WalletRepository _walletRepository;
  final CreateDefaultWalletsUsecase _createDefaultWallets;

  RestoreVaultUsecase({
    required this._walletRepository,
    required CreateDefaultWalletsUsecase createDefaultWalletsUsecase,
  }) : _createDefaultWallets = createDefaultWalletsUsecase;

  // Orchestrates the still-throwing wallet core repo; the local try/catch is
  // the boundary, mapping any failure to a sanitized core failure.
  Future<Result<Null, RecoverBullCoreFailure>> execute({
    required DecryptedVault decryptedVault,
    // Forwarded as-is to `CreateDefaultWalletsUsecase.execute` — see that
    // param's own doc. `RecoverBullBloc` resolves this (via its own
    // birthday-picker UI, `WalletBirthdayLookupMode.recovery`) only when the
    // restored default Bitcoin wallet is about to opt into compact block
    // filters; `null` otherwise, which this use-case never second-guesses.
    WalletBirthdayCheckpoint? bitcoinBirthdayCheckpoint,
  }) async {
    try {
      final mnemonic = bip39.Mnemonic.fromWords(
        words: decryptedVault.mnemonic,
        language: bip39.Language.english,
        passphrase: '',
      );

      final restoredWallets = await _createDefaultWallets.execute(
        mnemonicWords: mnemonic.words,
        bitcoinBirthdayCheckpoint: bitcoinBirthdayCheckpoint,
      );

      for (final wallet in restoredWallets) {
        await _walletRepository.updateEncryptedBackupTime(
          time: DateTime.now(),
          walletId: wallet.id,
        );
      }

      log.fine('Vault restored');
      return const Ok(null);
    } catch (e, st) {
      log.severe(message: 'restoreVault failed', error: e, trace: st);
      return Err(RecoverBullUnexpectedCoreFailure(e.toString()));
    }
  }
}
