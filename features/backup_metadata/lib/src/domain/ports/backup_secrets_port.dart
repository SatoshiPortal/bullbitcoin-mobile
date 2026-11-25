import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../backup_metadata_failure.dart';
import '../entities/backup_content.dart';
import '../entities/backup_inventory.dart';

/// What a restore changed in the Secrets inventory, per owner.
final class SecretsRestoreReport {
  final int walletsMatched;
  final int walletsUnmatched;
  final int walletLabelsApplied;
  final int walletBirthdaysApplied;
  final int derivationsAdded;
  final int derivationsUpdated;

  /// The registry conflicted with this phone's records and nothing of it
  /// was written.
  final bool derivationsRefused;

  const SecretsRestoreReport({
    required this.walletsMatched,
    required this.walletsUnmatched,
    required this.walletLabelsApplied,
    required this.walletBirthdaysApplied,
    required this.derivationsAdded,
    required this.derivationsUpdated,
    this.derivationsRefused = false,
  });
}

/// The Secrets owner's side of a metadata backup: the BIP85 registry, the
/// public wallet match and the view scope. It never reaches a seed.
abstract interface class BackupSecretsPort {
  /// An opaque token naming the view the inventory reads now.
  @useResult
  Future<Result<String, BackupMetadataFailure>> viewScope();

  /// The recorded BIP85 children of the group's seed; empty for watch-only.
  @useResult
  Future<Result<List<BackupDerivation>, BackupMetadataFailure>> derivations(
    BackupGroup group,
  );

  /// Applies the wallet metadata and the registry of [content] to [group] and
  /// reports each owner's share. Public wallets are matched by network and
  /// descriptors; the registry is merged monotonically, all or nothing.
  /// Idempotent: a second call changes nothing more.
  @useResult
  Future<Result<SecretsRestoreReport, BackupMetadataFailure>> restore(
    BackupGroup group,
    BackupContent content,
  );
}
