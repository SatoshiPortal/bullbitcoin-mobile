import 'encrypted_vault.dart';
import 'vault_context.dart';
import 'vault_recovery.dart';
import '../recoverbull_failure.dart';

/// A completed external effect remains successful if local accounting fails.
final class VaultCompletion {
  final EncryptedVault vault;
  final VaultContext? verifiedContext;

  /// Verified imported identity awaiting successful wallet provisioning.
  /// Null for legacy completions and explicit unverified sibling imports.
  final VaultContext? pendingVerificationContext;
  final VaultRecovery? recovery;
  final RecoverBullFailure? warning;

  const VaultCompletion({
    required this.vault,
    this.verifiedContext,
    this.pendingVerificationContext,
    this.recovery,
    this.warning,
  });
}
