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

/// The live session an operation belongs to: the durable view it reads and
/// whether the authority still holds the exact generation it was issued in.
///
/// Every effect (journal write, upload, deletion, an owner's write, the
/// delivery of a discovery or a preview) asks [isCurrent] immediately before
/// it starts. A lock ends it for good, and reopening the same view is a new
/// session.
abstract interface class BackupSessionRef {
  /// Identifies the view to partition state by. It grants nothing.
  String get view;

  bool get isCurrent;
}

/// The Secrets owner's side of a metadata backup: the BIP85 registry, the
/// public wallet match and the session. It never reaches a seed.
abstract interface class BackupSecretsPort {
  /// The live session; an error while the inventory is locked.
  @useResult
  Future<Result<BackupSessionRef, BackupMetadataFailure>> session();

  /// The Bitcoin wallets of [network] visible in the session's view, each with
  /// Secrets' verdict of exclusivity (true: its BIP138 recipient keys are its
  /// own in every view). A wallet absent from the answer is not trusted.
  /// Nothing of another view is returned.
  @useResult
  Future<Result<Map<String, bool>, BackupMetadataFailure>> exclusivity(
    BackupSessionRef session,
    BitcoinNetwork network,
  );

  /// The recorded BIP85 children of the group's seed; empty for watch-only.
  @useResult
  Future<Result<List<BackupDerivation>, BackupMetadataFailure>> derivations(
    BackupSessionRef session,
    BackupGroup group,
  );

  /// Applies the wallet metadata and the registry of [content] to [group] and
  /// reports each owner's share. Public wallets are matched by network and
  /// descriptors; the registry is merged monotonically, all or nothing.
  /// Idempotent: a second call changes nothing more. Refused once [session]
  /// is no longer current.
  @useResult
  Future<Result<SecretsRestoreReport, BackupMetadataFailure>> restore(
    BackupSessionRef session,
    BackupGroup group,
    BackupContent content,
  );
}
