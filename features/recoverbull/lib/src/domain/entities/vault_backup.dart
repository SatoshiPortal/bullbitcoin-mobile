import 'package:secrets/secrets.dart' show VaultKey;

import 'encrypted_vault.dart';
import 'vault_context.dart';

/// Ephemeral result: the key and encrypted file must be stored separately.
final class VaultBackup {
  final EncryptedVault vault;
  final VaultKey key;
  final VaultContext context;

  const VaultBackup({
    required this.vault,
    required this.key,
    required this.context,
  });
}
