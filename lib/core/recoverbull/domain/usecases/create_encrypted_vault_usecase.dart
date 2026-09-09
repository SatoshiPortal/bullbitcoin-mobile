import 'dart:convert';

import 'package:bb_mobile/core/recoverbull/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bull_logger/bull_logger.dart';
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
    Result<
      ({EncryptedVault vault, String vaultKey, String walletId}),
      RecoverBullCoreFailure
    >
  >
  execute({String? fingerprint}) async {
    try {
      final bitcoinWallets = await _walletRepository.getWallets(
        onlyBitcoin: true,
        onlyDefaults: fingerprint == null ? true : null,
      );

      if (bitcoinWallets.isEmpty) {
        return const Err(
          RecoverBullUnexpectedCoreFailure('No Bitcoin wallet found'),
        );
      }

      final matchingWallets = fingerprint == null
          ? bitcoinWallets
          : bitcoinWallets.where(
              (wallet) =>
                  wallet.singleLocalSeedFingerprint ==
                  fingerprint.toLowerCase(),
            );
      if (matchingWallets.isEmpty) {
        return const Err(
          RecoverBullUnexpectedCoreFailure(
            'No single-seed Bitcoin wallet found for the selected seed',
          ),
        );
      }
      final wallet = matchingWallets.first;
      final seedFingerprint =
          fingerprint?.toLowerCase() ?? wallet.singleLocalSeedFingerprint;
      if (seedFingerprint == null) {
        return const Err(
          RecoverBullUnexpectedCoreFailure('No local seed selected'),
        );
      }
      final seed = await _seedRepository.get(seedFingerprint);
      final seedModel = SeedModel.fromEntity(seed);
      final mnemonic = switch (seedModel) {
        MnemonicSeedModel(:final mnemonicWords) => mnemonicWords,
        _ => null,
      };
      if (mnemonic == null) {
        return const Err(
          RecoverBullUnexpectedCoreFailure(
            'Selected seed is not a mnemonic seed',
          ),
        );
      }
      final xprv = Bip32Derivation.getXprvFromSeed(seed.bytes, wallet.network);

      final toBackup = DecryptedVault(
        mnemonic: mnemonic,
        masterFingerprint: seedFingerprint,
        isEncryptedVaultTested: wallet.isEncryptedVaultTested,
        isPhysicalBackupTested: wallet.isPhysicalBackupTested,
        latestEncryptedBackup: wallet.latestEncryptedBackup,
        latestPhysicalBackup: wallet.latestPhysicalBackup,
      );
      final plaintext = json.encode(toBackup.toJson());
      // Derive the backup key using BIP85
      final derivationPath = RecoverbullBip85Utils.generateBackupKeyPath();
      final backupKey = RecoverbullBip85Utils.deriveBackupKey(
        xprv,
        derivationPath,
      );

      return _recoverBullRepository
          .createVault(
            vaultKey: backupKey,
            plaintext: plaintext,
            derivationPath: derivationPath,
          )
          .map(
            (vault) => (vault: vault, vaultKey: backupKey, walletId: wallet.id),
          );
    } catch (e, st) {
      log.severe(message: 'createEncryptedVault failed', error: e, trace: st);
      return Err(RecoverBullUnexpectedCoreFailure(e.toString()));
    }
  }
}
