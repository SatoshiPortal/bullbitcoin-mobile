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

final class WalletMetadataContributorApplyOutcome {
  final String contributorType;
  final int intendedCount;
  final int restoredCount;
  final int alreadyPresentCount;
  final int preservedLocalConflictCount;
  final int deferredMissingWalletCount;
  final int failedStorageCount;
  final bool storageFailed;
  final bool localProjectionMatchesSnapshot;

  factory WalletMetadataContributorApplyOutcome.success(
    WalletMetadataContributorApplySummary summary,
  ) {
    return WalletMetadataContributorApplyOutcome._(
      contributorType: summary.contributorType,
      intendedCount: summary.intendedCount,
      restoredCount: summary.restoredCount,
      alreadyPresentCount: summary.alreadyPresentCount,
      preservedLocalConflictCount: summary.preservedLocalConflictCount,
      deferredMissingWalletCount: summary.deferredMissingWalletCount,
      failedStorageCount: 0,
      storageFailed: false,
      localProjectionMatchesSnapshot: summary.localProjectionMatchesSnapshot,
    );
  }

  factory WalletMetadataContributorApplyOutcome.storageFailure({
    required String contributorType,
    required int intendedCount,
  }) {
    if (contributorType.isEmpty || intendedCount < 0) {
      throw ArgumentError('wallet metadata storage failure is invalid');
    }
    return WalletMetadataContributorApplyOutcome._(
      contributorType: contributorType,
      intendedCount: intendedCount,
      restoredCount: 0,
      alreadyPresentCount: 0,
      preservedLocalConflictCount: 0,
      deferredMissingWalletCount: 0,
      failedStorageCount: intendedCount,
      storageFailed: true,
      localProjectionMatchesSnapshot: false,
    );
  }

  const WalletMetadataContributorApplyOutcome._({
    required this.contributorType,
    required this.intendedCount,
    required this.restoredCount,
    required this.alreadyPresentCount,
    required this.preservedLocalConflictCount,
    required this.deferredMissingWalletCount,
    required this.failedStorageCount,
    required this.storageFailed,
    required this.localProjectionMatchesSnapshot,
  });
}

enum WalletMetadataRecoveryApplyStatus { complete, incomplete }

final class WalletMetadataRecoveryApplyResult {
  final WalletMetadataRecoveryApplyStatus status;
  final List<WalletMetadataContributorApplyOutcome> contributorOutcomes;
  final int unsupportedRecordCount;
  final int unsupportedSectionCount;
  final int invalidRecordCount;

  WalletMetadataRecoveryApplyResult({
    required this.status,
    required List<WalletMetadataContributorApplyOutcome> contributorOutcomes,
    required this.unsupportedRecordCount,
    required this.unsupportedSectionCount,
    required this.invalidRecordCount,
  }) : contributorOutcomes = List.unmodifiable(contributorOutcomes) {
    if (unsupportedRecordCount < 0 ||
        unsupportedSectionCount < 0 ||
        invalidRecordCount < 0) {
      throw ArgumentError('wallet metadata skipped counts are invalid');
    }
    if (this.contributorOutcomes
            .map((outcome) => outcome.contributorType)
            .toSet()
            .length !=
        this.contributorOutcomes.length) {
      throw ArgumentError('wallet metadata apply outcomes repeat a type');
    }
  }

  bool get publicationBlocked =>
      status != WalletMetadataRecoveryApplyStatus.complete;

  int get unsupportedCount => unsupportedRecordCount + unsupportedSectionCount;

  int get restoredCount => contributorOutcomes.fold(
    0,
    (sum, outcome) => sum + outcome.restoredCount,
  );

  int get alreadyPresentCount => contributorOutcomes.fold(
    0,
    (sum, outcome) => sum + outcome.alreadyPresentCount,
  );

  int get preservedLocalConflictCount => contributorOutcomes.fold(
    0,
    (sum, outcome) => sum + outcome.preservedLocalConflictCount,
  );

  int get deferredMissingWalletCount => contributorOutcomes.fold(
    0,
    (sum, outcome) => sum + outcome.deferredMissingWalletCount,
  );

  int get failedStorageCount => contributorOutcomes.fold(
    0,
    (sum, outcome) => sum + outcome.failedStorageCount,
  );
}
