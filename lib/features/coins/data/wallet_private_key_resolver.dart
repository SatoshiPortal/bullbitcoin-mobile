import 'dart:typed_data';

import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:proof_of_funds/proof_of_funds.dart';

/// Implements the `proof_of_funds` package's [PrivateKeyResolver] port over
/// BULL's wallet layer: given a scriptPubkey, derives the raw private key that
/// controls it for a specific wallet.
///
/// Security: the resolved key is secret material. It is derived on demand and
/// handed straight to the signing engine; this adapter never logs, caches, or
/// stores it.
class WalletPrivateKeyResolver implements PrivateKeyResolver {
  const WalletPrivateKeyResolver({
    required this.walletRepository,
    required this.walletId,
  });

  final BitcoinWalletRepository walletRepository;
  final String walletId;

  @override
  Future<Uint8List> keyForScript(Uint8List scriptPubKey) {
    return walletRepository.derivePrivateKeyForScript(
      walletId: walletId,
      scriptPubkey: scriptPubKey,
    );
  }
}
