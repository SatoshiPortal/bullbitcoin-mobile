import 'dart:typed_data';

import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bip32_keys/bip32_keys.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:convert/convert.dart';

/// If the key server is down
class UpdateLatestEncryptedVaultTestUsecase {
  final WalletRepository _walletRepository;

  UpdateLatestEncryptedVaultTestUsecase({
    required WalletRepository walletRepository,
  }) : _walletRepository = walletRepository;

  Future<void> execute({required DecryptedVault decryptedVault}) async {
    try {
      final mnemonic = bip39.Mnemonic.fromWords(
        words: decryptedVault.mnemonic,
        language: bip39.Language.english,
        passphrase: '',
      );

      final decodedRoot = Bip32Keys.fromSeed(Uint8List.fromList(mnemonic.seed));
      final decodedFingerprint = hex.encode(decodedRoot.fingerprint);

      final availableWallets = await _walletRepository.getWallets(
        onlyDefaults: true,
        environment: Environment.mainnet,
      );

      for (final wallet in availableWallets) {
        if (wallet.masterFingerprint == decodedFingerprint) {
          await _walletRepository.updateEncryptedBackupTime(
            time: DateTime.now(),
            walletId: wallet.id,
          );
        } else {
          log.warning(
            'The vault mnemonic does not match the current default wallet.',
          );
          await _walletRepository.updateEncryptedBackupTime(
            time: null,
            walletId: wallet.id,
          );
        }
      }
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      rethrow;
    }
  }
}
