import 'dart:convert';
import 'dart:typed_data';

import '../repositories/recoverbull_repository.dart';
import '../entities/decrypted_vault.dart';
import '../entities/encrypted_vault.dart';
import '../recoverbull_failure.dart';
import '../recoverbull_seed_port.dart';
import '../repositories/recoverbull_wallet_repository.dart';
import 'package:bip32_keys/bip32_keys.dart';
import 'package:bull_logger/bull_logger.dart';
import '../../utils/recoverbull_bip85.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:primitives/primitives.dart';

class CreateEncryptedVaultUsecase {
  final LogSink log;
  final RecoverBullRepository _recoverBullRepository;
  final RecoverBullSeedPort _seedRepository;
  final RecoverBullWalletRepository _walletRepository;

  CreateEncryptedVaultUsecase({
    required this.log,
    required this._recoverBullRepository,
    required this._seedRepository,
    required this._walletRepository,
  });

  // Orchestrates wallet + seed (still-throwing core repos) and the recoverbull
  // repo. The local try/catch is the boundary for the wallet/seed calls; the
  // recoverbull repo already returns a Result that we forward.
  Future<Result<({EncryptedVault vault, String vaultKey}), RecoverBullFailure>>
  execute() async {
    try {
      final defaultBitcoinWallets = await _walletRepository.getWallets(
        onlyBitcoin: true,
        onlyDefaults: true,
      );

      if (defaultBitcoinWallets.isEmpty) {
        return const Err(
          RecoverBullUnexpectedFailure('No default Bitcoin wallet found'),
        );
      }

      // The default wallet is used to derive the backup key
      final defaultWallet = defaultBitcoinWallets.first;
      final defaultSeed = await _seedRepository.getSeed(
        defaultWallet.masterFingerprint,
      );
      final mnemonic = defaultSeed.mnemonicWords;
      if (mnemonic.isEmpty) {
        return const Err(RecoverBullUnexpectedFailure('Invalid seed'));
      }
      try {
        Mnemonic.fromWords(words: mnemonic);
      } catch (_) {
        return const Err(RecoverBullUnexpectedFailure('Invalid seed'));
      }
      // BIP85 derivation is network-independent. Always serialize the root
      // with the canonical mainnet version expected by bip85_entropy.
      final defaultXprv = Bip32Keys.fromSeed(
        Uint8List.fromList(defaultSeed.bytes),
      ).toBase58();

      final toBackup = DecryptedVault(
        mnemonic: mnemonic,
        masterFingerprint: defaultWallet.masterFingerprint,
        // These fields belong to the old vault-file format. Their authoritative
        // state is package-owned in recoverbull.sqlite, never wallet metadata.
        isEncryptedVaultTested: false,
        isPhysicalBackupTested: defaultWallet.isPhysicalBackupTested,
        latestEncryptedBackup: null,
        latestPhysicalBackup: defaultWallet.latestPhysicalBackup,
      );
      final plaintext = json.encode(toBackup.toJson());
      final derivationPath = RecoverbullBip85Utils.generateBackupKeyPath();

      final result = await _recoverBullRepository.createVault(
        rootXprv: defaultXprv,
        plaintext: plaintext,
        derivationPath: derivationPath,
      );
      return result.map(
        (created) => (vault: created.vault, vaultKey: created.vaultKey),
      );
    } catch (_, st) {
      log.error('createEncryptedVault failed', trace: st);
      return const Err(RecoverBullUnexpectedFailure('Unable to create vault'));
    }
  }
}
