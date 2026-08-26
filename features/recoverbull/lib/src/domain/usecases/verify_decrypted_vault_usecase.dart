import 'dart:typed_data';

import 'package:bip32_keys/bip32_keys.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:bull_recoverbull/src/domain/entity/decrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/ports.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:convert/convert.dart' as convert;
import 'package:primitives/primitives.dart';

enum VaultVerificationResult { match, noCurrentWallet, mismatch }

class VerifyDecryptedVaultUsecase {
  final RecoverBullWalletRepositoryPort _walletRepository;

  const VerifyDecryptedVaultUsecase(this._walletRepository);

  Future<Result<VaultVerificationResult, RecoverBullCoreFailure>> execute({
    required DecryptedVault decryptedVault,
  }) async {
    try {
      final mnemonic = Mnemonic.fromWords(words: decryptedVault.mnemonic);
      final root = Bip32Keys.fromSeed(Uint8List.fromList(mnemonic.seed));
      final decrypted = convert.hex.encode(root.fingerprint);
      final wallets = await _walletRepository.getWallets(
        onlyBitcoin: true,
        onlyDefaults: true,
      );
      if (wallets.isEmpty) {
        return const Ok(VaultVerificationResult.noCurrentWallet);
      }
      final current = _normalize(wallets.first.masterFingerprint);
      return Ok(
        current.isNotEmpty && current == decrypted
            ? VaultVerificationResult.match
            : VaultVerificationResult.mismatch,
      );
    } catch (_) {
      return const Err(
        RecoverBullUnexpectedCoreFailure('Unable to verify vault'),
      );
    }
  }

  static String _normalize(String value) =>
      value.replaceAll(RegExp(r'\s'), '').toLowerCase();
}
