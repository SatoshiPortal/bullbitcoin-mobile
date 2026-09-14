import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_contents.dart';

/// What a backup holds for someone who arrived with the twelve words only.
///
/// The vaults are the same summaries the seed-bound read describes, so recovery
/// has one vault shape whichever way the backup was opened.
///
/// [parentFingerprint] is what the authenticated plaintext says about the seed
/// that wrote the backup. It is a source fact for display and matching, never
/// evidence that this app owns that seed, and nothing local is fenced, labelled
/// or checkpointed on the strength of it.
final class WalletBackupWordsExtraction {
  final List<WalletBackupVaultSummary> vaults;
  final String parentFingerprint;

  WalletBackupWordsExtraction({
    required Iterable<WalletBackupVaultSummary> vaults,
    required this.parentFingerprint,
  }) : vaults = List.unmodifiable(vaults);
}
