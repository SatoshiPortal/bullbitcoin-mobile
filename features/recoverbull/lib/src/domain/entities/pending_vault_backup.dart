import 'encrypted_vault.dart';
import 'recoverbull_network.dart';

/// A prepared backup retained for a provider retry. It carries no key or password.
final class PendingVaultBackup {
  final EncryptedVault vault;
  final RecoverBullNetwork network;

  const PendingVaultBackup({required this.vault, required this.network});
}
