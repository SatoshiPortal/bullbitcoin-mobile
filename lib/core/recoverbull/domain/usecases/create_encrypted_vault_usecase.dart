import 'dart:convert';

import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/recoverbull_bip85.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

class CreateEncryptedVaultUsecase {
  final RecoverBullRepository _recoverBullRepository;
  final SeedRepository _seedRepository;
  final WalletRepository _walletRepository;

  CreateEncryptedVaultUsecase({
    required this._recoverBullRepository,
    required this._seedRepository,
    required this._walletRepository,
  });

  // Orchestrates wallet + seed (still-throwing core repos) and the recoverbull
  // repo. The local try/catch is the boundary for the wallet/seed calls; the
  // recoverbull repo already returns a Result that we forward.
  Future<
    Result<({EncryptedVault vault, String vaultKey}), RecoverBullCoreFailure>
  >
  execute() async {
    try {
      final defaultBitcoinWallets = await _walletRepository.getWallets(
        onlyBitcoin: true,
        onlyDefaults: true,
      );

      if (defaultBitcoinWallets.isEmpty) {
        return const Err(
          RecoverBullUnexpectedCoreFailure('No default Bitcoin wallet found'),
        );
      }

      // The default wallet is used to derive the backup key
      final defaultWallet = defaultBitcoinWallets.first;
      await _walletRepository.updateEncryptedBackupTime(
        time: DateTime.now(),
        walletId: defaultWallet.id,
      );
      final defaultSeed = await _seedRepository.get(
        defaultWallet.masterFingerprint,
      );
      final defaultSeedModel = SeedModel.fromEntity(defaultSeed);
      final mnemonic = switch (defaultSeedModel) {
        MnemonicSeedModel(:final mnemonicWords) => mnemonicWords,
        _ => null,
      };
      if (mnemonic == null) {
        return const Err(
          RecoverBullUnexpectedCoreFailure(
            'Default seed is not a mnemonic seed',
          ),
        );
      }
      final defaultXprv = Bip32Derivation.getXprvFromSeed(
        defaultSeed.bytes,
        defaultWallet.network,
      );

      final toBackup = DecryptedVault(
        mnemonic: mnemonic,
        masterFingerprint: defaultWallet.masterFingerprint,
        isEncryptedVaultTested: defaultWallet.isEncryptedVaultTested,
        isPhysicalBackupTested: defaultWallet.isPhysicalBackupTested,
        latestEncryptedBackup: defaultWallet.latestEncryptedBackup,
        latestPhysicalBackup: defaultWallet.latestPhysicalBackup,
      );
      final plaintext = json.encode(toBackup.toJson());
      // Derive the backup key using BIP85
      final derivationPath = RecoverbullBip85Utils.generateBackupKeyPath();
      final backupKey = RecoverbullBip85Utils.deriveBackupKey(
        defaultXprv,
        derivationPath,
      );

      return _recoverBullRepository
          .createVault(
            vaultKey: backupKey,
            plaintext: plaintext,
            derivationPath: derivationPath,
          )
          .map((vault) => (vault: vault, vaultKey: backupKey));
    } catch (e, st) {
      log.severe(message: 'createEncryptedVault failed', error: e, trace: st);
      return Err(RecoverBullUnexpectedCoreFailure(e.toString()));
    }
  }
}
