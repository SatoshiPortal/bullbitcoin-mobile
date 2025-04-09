import 'dart:convert';

import 'package:bb_mobile/core/recoverbull/domain/entity/backup_info.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/recoverbull_wallet.dart';
import 'package:bb_mobile/core/recoverbull/domain/errors/recover_wallet_error.dart';
import 'package:bb_mobile/core/recoverbull/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/key_server/domain/errors/key_server_error.dart';
import 'package:flutter/foundation.dart';

/// If the key server is down
class RestoreEncryptedVaultFromBackupKeyUsecase {
  final RecoverBullRepository _recoverBull;
  final WalletRepository _walletRepository;
  final CreateDefaultWalletsUsecase _createDefaultWallets;

  RestoreEncryptedVaultFromBackupKeyUsecase({
    required RecoverBullRepository recoverBullRepository,
    required WalletRepository walletRepository,
    required CreateDefaultWalletsUsecase createDefaultWalletsUsecase,
  })  : _recoverBull = recoverBullRepository,
        _walletRepository = walletRepository,
        _createDefaultWallets = createDefaultWalletsUsecase;

  Future<void> execute({
    required String backupFile,
    required String backupKey,
  }) async {
    try {
      final backupInfo = BackupInfo(backupFile: backupFile);
      if (backupInfo.isCorrupted) {
        throw const KeyServerError.invalidBackupFile();
      }

      final plaintext = _recoverBull.restoreBackupFile(backupFile, backupKey);

      final decodedPlaintext = json.decode(plaintext) as Map<String, dynamic>;
      final decodedRecoverbullWallets =
          RecoverBullWallet.fromJson(decodedPlaintext);

      final availableWallets = await _walletRepository.getWallets(
        onlyDefaults: true,
        onlyBitcoin: true,
        environment: Environment.mainnet,
      );

      if (availableWallets.isNotEmpty) {
        // There should be only one default Bitcoin wallet for mainnet
        final defaultWallet = availableWallets.first;
        if (defaultWallet.masterFingerprint ==
            decodedRecoverbullWallets.masterFingerprint) {
          await _walletRepository.updateEncryptedBackupTime(
            DateTime.now(),
            walletId: defaultWallet.id,
          );
          throw const DefaultWalletAlreadyExistsError();
        } else {
          throw const WalletMismatchError();
        }
      }

      final wallets = await _createDefaultWallets.execute(
        mnemonicWords: decodedRecoverbullWallets.mnemonic,
      );

      debugPrint('Default wallets created');
      final bitcoinWallet = wallets.firstWhere(
        (wallet) => wallet.network == Network.bitcoinMainnet,
      );
      final walletId = bitcoinWallet.id;
      await _wallet.updateBackupInfo(
        isEncryptedVaultTested: true,
        isPhysicalBackupTested:
            decodedRecoverbullWallets.isPhysicalBackupTested,
        latestEncryptedBackup: decodedRecoverbullWallets.latestEncryptedBackup,
        latestPhysicalBackup: decodedRecoverbullWallets.latestPhysicalBackup,
        walletId: walletId,
      );

      debugPrint('Default wallet updated');
    } catch (e) {
      debugPrint('$RestoreEncryptedVaultFromBackupKeyUsecase: $e');
      rethrow;
    }
  }
}
