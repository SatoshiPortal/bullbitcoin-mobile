import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_vault_entry.dart';

/// What a backup holds for someone who arrived with the twelve words only.
///
/// [parentFingerprint] is what the authenticated plaintext says about the seed
/// that wrote the backup. It is a source fact for display and matching, never
/// evidence that this app owns that seed, and nothing local is fenced, labelled
/// or checkpointed on the strength of it (plan 5.2).
final class WalletBackupWordsExtraction {
  final List<WalletBackupVaultEntry> vaults;
  final String parentFingerprint;

  WalletBackupWordsExtraction({
    required Iterable<WalletBackupVaultEntry> vaults,
    required this.parentFingerprint,
  }) : vaults = List.unmodifiable(vaults);
}
