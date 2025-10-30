import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;

/// If the key server is down
class RestoreVaultUsecase {
  final WalletRepository _walletRepository;
  final CreateDefaultWalletsUsecase _createDefaultWallets;

  RestoreVaultUsecase({
    required WalletRepository walletRepository,
    required CreateDefaultWalletsUsecase createDefaultWalletsUsecase,
  }) : _walletRepository = walletRepository,
       _createDefaultWallets = createDefaultWalletsUsecase;

  Future<void> execute({required DecryptedVault decryptedVault}) async {
    try {
      final mnemonic = bip39.Mnemonic.fromWords(
        words: decryptedVault.mnemonic,
        language: bip39.Language.english,
        passphrase: '',
      );

      final restoredWallets = await _createDefaultWallets.execute(
        mnemonicWords: mnemonic.words,
      );

      for (final wallet in restoredWallets) {
        await _walletRepository.updateEncryptedBackupTime(
          time: DateTime.now(),
          walletId: wallet.id,
        );
      }

      log.fine('Vault restored');
    } catch (e) {
      log.severe('$RestoreVaultUsecase: $e');
      rethrow;
    }
  }
}
