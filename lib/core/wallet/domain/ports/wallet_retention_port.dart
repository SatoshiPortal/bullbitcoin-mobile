import 'package:primitives/primitives.dart' show Fingerprint;

/// Reports whether another capability retains a wallet or its secret.
/// A failure to check must cause callers to refuse destructive operations.
abstract interface class WalletRetentionPort {
  Future<bool> retainsWallet(String walletId);
  Future<bool> retainsSecret(Fingerprint secretId);
}
