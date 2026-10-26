import 'dart:typed_data';

import 'package:bip32_keys/bip32_keys.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import '../entities/decrypted_vault.dart';
import '../entities/recoverbull_network.dart';
import '../entities/recoverbull_wallet.dart';
import '../repositories/recoverbull_wallet_repository.dart';
import '../recoverbull_failure.dart';
import '../recoverbull_settings_port.dart';
import 'package:convert/convert.dart' as convert;
import 'package:primitives/primitives.dart';

enum VaultVerificationResult { match, noCurrentWallet, mismatch }

/// [network] is the network of the wallet a matching vault belongs to; it is
/// null unless [result] is [VaultVerificationResult.match].
typedef VaultVerification = ({
  VaultVerificationResult result,
  RecoverBullNetwork? network,
});

class VerifyDecryptedVaultUsecase {
  final RecoverBullWalletRepository _walletRepository;
  final RecoverBullSettingsPort _settings;

  const VerifyDecryptedVaultUsecase(this._walletRepository, this._settings);

  Future<Result<VaultVerification, RecoverBullFailure>> execute({
    required DecryptedVault decryptedVault,
  }) async {
    try {
      final mnemonic = Mnemonic.fromWords(words: decryptedVault.mnemonic);
      final root = Bip32Keys.fromSeed(Uint8List.fromList(mnemonic.seed));
      final decrypted = convert.hex.encode(root.fingerprint);
      // The current wallet is the default wallet of the network the app runs
      // on; another network's default wallet may hold another seed.
      final walletsResult = await _walletRepository.getWallets(
        onlyBitcoin: true,
        onlyDefaults: true,
        network: await _settings.fetchNetwork(),
      );
      final List<RecoverBullWallet> wallets;
      switch (walletsResult) {
        case Ok(:final value):
          wallets = value;
        case Err(:final failure):
          return Err(failure);
      }
      if (wallets.isEmpty) {
        return const Ok((
          result: VaultVerificationResult.noCurrentWallet,
          network: null,
        ));
      }
      final wallet = wallets.first;
      final current = _normalize(wallet.masterFingerprint);
      return Ok(
        current.isNotEmpty && current == decrypted
            ? (result: VaultVerificationResult.match, network: wallet.network)
            : (result: VaultVerificationResult.mismatch, network: null),
      );
    } catch (_) {
      return const Err(RecoverBullUnexpectedFailure('Unable to verify vault'));
    }
  }

  static String _normalize(String value) =>
      value.replaceAll(RegExp(r'\s'), '').toLowerCase();
}
