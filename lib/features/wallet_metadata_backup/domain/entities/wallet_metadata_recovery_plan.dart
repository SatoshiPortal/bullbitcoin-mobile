import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_record.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_remote_head.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_snapshot.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_contributor.dart';

final class WalletMetadataContributorImportPlan {
  final String contributorType;
  final List<int> sectionVersions;
  final List<WalletMetadataImportIntent> intents;

  WalletMetadataContributorImportPlan({
    required this.contributorType,
    required List<int> sectionVersions,
    required List<WalletMetadataImportIntent> intents,
  }) : sectionVersions = List.unmodifiable(sectionVersions),
       intents = List.unmodifiable(intents) {
    if (contributorType.isEmpty ||
        this.sectionVersions.isEmpty ||
        this.intents.any(
          (intent) => intent.contributorType != contributorType,
        )) {
      throw ArgumentError('wallet metadata contributor plan is invalid');
    }
  }
}

final class WalletMetadataInvalidRecord {
  final String recordType;
  final int recordVersion;
  final WalletMetadataRecordInvalidReason reason;

  const WalletMetadataInvalidRecord({
    required this.recordType,
    required this.recordVersion,
    required this.reason,
  });
}

final class WalletMetadataRecoveryPlan {
  final WalletMetadataRemoteHead selectedHead;
  final List<WalletMetadataContributorImportPlan> contributorPlans;
  final List<WalletMetadataRecord> unsupportedRecords;
  final List<WalletMetadataSection> unsupportedSections;
  final List<WalletMetadataInvalidRecord> invalidRecords;

  WalletMetadataRecoveryPlan({
    required this.selectedHead,
    required List<WalletMetadataContributorImportPlan> contributorPlans,
    required List<WalletMetadataRecord> unsupportedRecords,
    required List<WalletMetadataSection> unsupportedSections,
    required List<WalletMetadataInvalidRecord> invalidRecords,
  }) : contributorPlans = List.unmodifiable(contributorPlans),
       unsupportedRecords = List.unmodifiable(unsupportedRecords),
       unsupportedSections = List.unmodifiable(unsupportedSections),
       invalidRecords = List.unmodifiable(invalidRecords) {
    if (this.contributorPlans
            .map((plan) => plan.contributorType)
            .toSet()
            .length !=
        this.contributorPlans.length) {
      throw ArgumentError('wallet metadata contributor plans repeat a type');
    }
  }

  bool get hasUnsupportedMetadata =>
      unsupportedRecords.isNotEmpty || unsupportedSections.isNotEmpty;

  int get plannedRecordCount =>
      contributorPlans.fold<int>(0, (sum, plan) => sum + plan.intents.length);
}

enum WalletMetadataRecoveryStatus {
  snapshot,
  snapshotWithUnsupportedMetadata,
  noSnapshotFound,
  remoteUnavailable,
  unsupportedNewerEnvelope,
}

final class WalletMetadataRecoveryResult {
  final WalletMetadataRecoveryStatus status;
  final WalletMetadataRecoveryPlan? plan;

  const WalletMetadataRecoveryResult._({required this.status, this.plan});

  factory WalletMetadataRecoveryResult.ready(WalletMetadataRecoveryPlan plan) {
    return WalletMetadataRecoveryResult._(
      status: plan.hasUnsupportedMetadata
          ? WalletMetadataRecoveryStatus.snapshotWithUnsupportedMetadata
          : WalletMetadataRecoveryStatus.snapshot,
      plan: plan,
    );
  }

  const WalletMetadataRecoveryResult.noSnapshotFound()
    : this._(status: WalletMetadataRecoveryStatus.noSnapshotFound);

  const WalletMetadataRecoveryResult.remoteUnavailable()
    : this._(status: WalletMetadataRecoveryStatus.remoteUnavailable);

  const WalletMetadataRecoveryResult.unsupportedNewerEnvelope()
    : this._(status: WalletMetadataRecoveryStatus.unsupportedNewerEnvelope);
}
