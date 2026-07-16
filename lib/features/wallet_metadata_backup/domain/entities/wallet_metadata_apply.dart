final class WalletMetadataApplyContext {
  final Set<String> createdWalletRefs;

  WalletMetadataApplyContext({required Set<String> createdWalletRefs})
    : createdWalletRefs = Set.unmodifiable(createdWalletRefs) {
    if (this.createdWalletRefs.any((walletRef) => walletRef.isEmpty)) {
      throw ArgumentError.value(createdWalletRefs, 'createdWalletRefs');
    }
  }
}

final class WalletMetadataContributorApplySummary {
  final String contributorType;
  final int intendedCount;
  final int restoredCount;
  final int alreadyPresentCount;
  final int preservedLocalConflictCount;
  final int deferredMissingWalletCount;
  final bool localProjectionMatchesSnapshot;

  WalletMetadataContributorApplySummary({
    required this.contributorType,
    required this.intendedCount,
    required this.restoredCount,
    required this.alreadyPresentCount,
    required this.preservedLocalConflictCount,
    required this.deferredMissingWalletCount,
    required this.localProjectionMatchesSnapshot,
  }) {
    final counts = [
      intendedCount,
      restoredCount,
      alreadyPresentCount,
      preservedLocalConflictCount,
      deferredMissingWalletCount,
    ];
    if (contributorType.isEmpty || counts.any((count) => count < 0)) {
      throw ArgumentError('wallet metadata apply summary is invalid');
    }
    final handledCount =
        restoredCount +
        alreadyPresentCount +
        preservedLocalConflictCount +
        deferredMissingWalletCount;
    if (handledCount != intendedCount) {
      throw ArgumentError('wallet metadata apply counts do not balance');
    }
    if (localProjectionMatchesSnapshot &&
        (preservedLocalConflictCount != 0 || deferredMissingWalletCount != 0)) {
      throw ArgumentError('a divergent apply cannot match the snapshot');
    }
  }
}
