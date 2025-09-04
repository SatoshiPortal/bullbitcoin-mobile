import 'dart:convert';

import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/errors/recover_wallet_error.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';

/// If the key server is down
class RestoreEncryptedVaultFromVaultKeyUsecase {
  final RecoverBullRepository _recoverBull;
  final WalletRepository _walletRepository;
  final CreateDefaultWalletsUsecase _createDefaultWallets;

  RestoreEncryptedVaultFromVaultKeyUsecase({
    required RecoverBullRepository recoverBullRepository,
    required WalletRepository walletRepository,
    required CreateDefaultWalletsUsecase createDefaultWalletsUsecase,
  }) : _recoverBull = recoverBullRepository,
       _walletRepository = walletRepository,
       _createDefaultWallets = createDefaultWalletsUsecase;

  Future<void> execute({
    required EncryptedVault vault,
    required String vaultKey,
  }) async {
    try {
      final plaintext = _recoverBull.restoreJsonVault(vault.toFile(), vaultKey);

      final decodedPlaintext = json.decode(plaintext) as Map<String, dynamic>;
      final decodedRecoverbullWallets = DecryptedVault.fromJson(
        decodedPlaintext,
      );
      // check if the wallet already exists

      final availableWallets = await _walletRepository.getWallets(
        onlyDefaults: true,
        environment: Environment.mainnet,
      );
      // in onboarding there will never be available wallets
      // this is mainly for test flows
      for (final defaultWallet in availableWallets) {
        if (defaultWallet.masterFingerprint ==
            decodedRecoverbullWallets.masterFingerprint) {
          await _walletRepository.updateEncryptedBackupTime(
            DateTime.now(),
            walletId: defaultWallet.id,
          );
          // These are only cases for test flows.
          throw const TestFlowDefaultWalletAlreadyExistsError();
        } else {
          throw const TestFlowWalletMismatchError();
        }
      }

      final restoredWallets = await _createDefaultWallets.execute(
        mnemonicWords: decodedRecoverbullWallets.mnemonic,
      );
      log.fine('Default wallets created');
      for (final wallet in restoredWallets) {
        await _walletRepository.updateBackupInfo(
          isEncryptedVaultTested: true,
          isPhysicalBackupTested:
              decodedRecoverbullWallets.isPhysicalBackupTested,
          latestEncryptedBackup: DateTime.now(),
          latestPhysicalBackup: decodedRecoverbullWallets.latestPhysicalBackup,
          walletId: wallet.id,
        );
      }

      log.info('Default wallets updated');
    } catch (e) {
      log.severe('$RestoreEncryptedVaultFromVaultKeyUsecase: $e');
      rethrow;
    }
  }
}
