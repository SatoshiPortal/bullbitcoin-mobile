import 'labels_snapshot.dart';

/// A label that differs between this phone and the backup.
final class LabelConflict {
  final BackupLabelChain chain;
  final BackupLabelType type;
  final String ref;
  final String localLabel;
  final String incomingLabel;

  const LabelConflict({
    required this.chain,
    required this.type,
    required this.ref,
    required this.localLabel,
    required this.incomingLabel,
  });

  /// One conflict per record identity.
  @override
  bool operator ==(Object other) =>
      other is LabelConflict &&
      other.chain == chain &&
      other.type == type &&
      other.ref == ref;

  @override
  int get hashCode => Object.hash(chain, type, ref);
}

/// A freeze from the backup, checked against its attributed wallet only.
final class FreezeRequest {
  final String walletId;
  final String outpoint;

  FreezeRequest({required this.walletId, required this.outpoint}) {
    if (walletId.isEmpty || outpoint.isEmpty) {
      throw ArgumentError('A freeze needs a wallet and an outpoint');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is FreezeRequest &&
      other.walletId == walletId &&
      other.outpoint == outpoint;

  @override
  int get hashCode => Object.hash(walletId, outpoint);
}

/// Additive merge preview; nothing is written before `apply`.
final class MergePlan {
  final String groupId;

  /// Digest of the local labels the plan was computed from; `apply` rejects
  /// the plan when they changed since.
  final String baseDigest;
  final List<BackupLabelRecord> additions;
  final int unchanged;
  final List<LabelConflict> conflicts;
  final List<FreezeRequest> freezes;

  MergePlan({
    required this.groupId,
    required this.baseDigest,
    required List<BackupLabelRecord> additions,
    required this.unchanged,
    required List<LabelConflict> conflicts,
    required List<FreezeRequest> freezes,
  }) : additions = List.unmodifiable(additions),
       conflicts = List.unmodifiable(conflicts),
       freezes = List.unmodifiable(freezes);
}

enum ConflictResolution { keepLocal, useBackup }

/// Missing entries keep the local label.
final class MergeChoices {
  final Map<LabelConflict, ConflictResolution> resolutions;

  MergeChoices(Map<LabelConflict, ConflictResolution> resolutions)
    : resolutions = Map.unmodifiable(resolutions);
}

enum LabelRejection { reservedLabel, notOwned, invalid }

enum FreezeOutcome { applied, pendingDiscovery, notOwned, failed }

/// Per-channel result; a partial commit is reported, never hidden.
final class ApplyReport {
  final int labelsApplied;
  final int labelsUnchanged;
  final Map<LabelRejection, int> labelsRejected;
  final Map<FreezeRequest, FreezeOutcome> freezes;

  ApplyReport({
    required this.labelsApplied,
    required this.labelsUnchanged,
    required Map<LabelRejection, int> labelsRejected,
    required Map<FreezeRequest, FreezeOutcome> freezes,
  }) : labelsRejected = Map.unmodifiable(labelsRejected),
       freezes = Map.unmodifiable(freezes);
}
