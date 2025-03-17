import 'dart:convert';

import 'package:bb_mobile/_core/domain/entities/seed.dart';
import 'package:bb_mobile/_core/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/_utils/bip32_derivation.dart';
import 'package:bb_mobile/_utils/bip85_derivation.dart';
import 'package:flutter/foundation.dart';

class CreateEncryptedBackupUsecase {
  final RecoverBullRepository _recoverBullRepository;
  final SeedRepository _seedRepository;
  final WalletMetadataRepository _walletMetadataRepository;
  CreateEncryptedBackupUsecase({
    required RecoverBullRepository recoverBullRepository,
    required SeedRepository seedRepository,
    required WalletMetadataRepository walletMetadataRepository,
  })  : _recoverBullRepository = recoverBullRepository,
        _seedRepository = seedRepository,
        _walletMetadataRepository = walletMetadataRepository;

  Future<String> execute({required String defaultWalletFingerPrint}) async {
    try {
      final wallets = await _walletMetadataRepository.getAll();
      if (wallets.isEmpty) {
        throw Exception(
          'No wallets available to create backup',
        );
      }
      late Seed defaultWalletSeed;
      final doesDeafaultFingerPrintSeedExist =
          await _seedRepository.exists(defaultWalletFingerPrint);
      if (doesDeafaultFingerPrintSeedExist) {
        defaultWalletSeed = await _seedRepository.get(defaultWalletFingerPrint);
      } else {
        debugPrint('Master seed not found, trying to fetch first seed');
        defaultWalletSeed = await _seedRepository.get(
          wallets
              .firstWhere(
                (e) => e.network.isBitcoin,
                orElse: () => wallets.first,
              )
              .masterFingerprint,
        );
      }

      final defaultWallet = wallets.firstWhere(
        (e) => e.masterFingerprint == defaultWalletSeed.masterFingerprint,
        orElse: () => throw "Default wallet not found",
      );
      final defaultWalletXpriv = Bip32Derivation.getXprvFromSeed(
        defaultWalletSeed.seedBytes,
        defaultWallet.network,
      );
      final derivationPath = Bip85Derivation.generateBackupKeyPath();
      final backupKey =
          Bip85Derivation.derive(defaultWalletXpriv, derivationPath)
              .sublist(0, 32);
      final encryptedBackup = await _recoverBullRepository.createBackupFile(
        backupKey: backupKey,
        seed: defaultWalletSeed,
        wallets: wallets,
      );

      // Append the path to the backup file
      final mapBackup = json.decode(encryptedBackup);
      mapBackup['path'] = derivationPath;
      return json.encode(mapBackup);
    } catch (e) {
      debugPrint('error creating encrypted backup: $e');
      rethrow;
    }
  }
}
