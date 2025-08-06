import 'dart:convert';

import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/recoverbull_wallet.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/bip85_derivation.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

class CreateEncryptedVaultUsecase {
  final RecoverBullRepository _recoverBullRepository;
  final SeedRepository _seedRepository;
  final WalletRepository _walletRepository;

  CreateEncryptedVaultUsecase({
    required RecoverBullRepository recoverBullRepository,
    required SeedRepository seedRepository,
    required WalletRepository walletRepository,
  }) : _recoverBullRepository = recoverBullRepository,
       _seedRepository = seedRepository,
       _walletRepository = walletRepository;

  Future<String> execute() async {
    try {
      // Get the default wallet
      final defaultBitcoinWallets = await _walletRepository.getWallets(
        onlyBitcoin: true,
        onlyDefaults: true,
      );

      if (defaultBitcoinWallets.isEmpty) {
        throw CreateEncryptedVaultException('No default Bitcoin wallet found');
      }

      // The default wallet is used to derive the backup key
      final defaultWallet = defaultBitcoinWallets.first;
      await _walletRepository.updateEncryptedBackupTime(
        DateTime.now(),
        walletId: defaultWallet.id,
      );
      final defaultFingerprint = defaultWallet.masterFingerprint;
      final defaultSeed = await _seedRepository.get(defaultFingerprint);
      final defaultSeedModel = SeedModel.fromEntity(defaultSeed);
      final mnemonic = switch (defaultSeedModel) {
        MnemonicSeedModel(:final mnemonicWords) => mnemonicWords,
        _ =>
          throw 'CreateEncryptedVaultUsecase: Default seed is not a bytes seed',
      };
      final defaultXprv = Bip32Derivation.getXprvFromSeed(
        defaultSeed.bytes,
        defaultWallet.network,
      );

      final toBackup = RecoverBullWallet(
        mnemonic: mnemonic,
        masterFingerprint: defaultWallet.masterFingerprint,
        isEncryptedVaultTested: defaultWallet.isEncryptedVaultTested,
        isPhysicalBackupTested: defaultWallet.isPhysicalBackupTested,
        latestEncryptedBackup: defaultWallet.latestEncryptedBackup,
        latestPhysicalBackup: defaultWallet.latestPhysicalBackup,
      );
      final plaintext = json.encode(toBackup.toJson());
      // Derive the backup key using BIP85
      final derivationPath = Bip85Derivation.generateBackupKeyPath();

      final backupKey = Bip85Derivation.deriveBackupKey(
        defaultXprv,
        derivationPath,
      );

      // Create an encrypted backup file
      final encryptedBackup = _recoverBullRepository.createBackupJson(
        backupKey,
        plaintext,
      );
      // Add the BIP85 derivation path (backup key) to the backup file
      final mapBackup = json.decode(encryptedBackup);
      mapBackup['path'] = derivationPath;

      return json.encode(mapBackup);
    } catch (e) {
      log.severe('$CreateEncryptedVaultUsecase: $e');
      throw CreateEncryptedVaultException(e.toString());
    }
  }
}

class CreateEncryptedVaultException implements Exception {
  final String message;

  CreateEncryptedVaultException(this.message);
}
