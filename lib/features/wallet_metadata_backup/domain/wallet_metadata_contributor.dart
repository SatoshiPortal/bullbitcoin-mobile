import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_apply.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_record.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_failure.dart';
import 'package:meta/meta.dart';

enum WalletMetadataRecordInvalidReason {
  unsupportedTypeOrVersion,
  invalidScope,
  invalidIdentity,
  invalidPayload,
}

final class WalletMetadataImportIntent {
  final String contributorType;
  final WalletMetadataRecord record;

  WalletMetadataImportIntent({
    required this.contributorType,
    required this.record,
  }) {
    if (contributorType != record.type) {
      throw ArgumentError.value(contributorType, 'contributorType');
    }
  }

  String get recordIdentity => record.identity;
}

sealed class WalletMetadataRecordValidation {
  const WalletMetadataRecordValidation();
}

final class WalletMetadataRecordValid extends WalletMetadataRecordValidation {
  final WalletMetadataImportIntent intent;

  const WalletMetadataRecordValid(this.intent);
}

final class WalletMetadataRecordInvalid extends WalletMetadataRecordValidation {
  final WalletMetadataRecordInvalidReason reason;

  const WalletMetadataRecordInvalid(this.reason);
}

abstract interface class WalletMetadataContributor {
  String get recordType;

  Set<int> get supportedVersions;

  WalletMetadataRecordValidation validateRecord(WalletMetadataRecord record);

  @useResult
  Future<Result<List<WalletMetadataRecord>, WalletMetadataBackupFailure>>
  exportRecords();
}

/// A contributor-owned, post-commit source for dirty tracking.
abstract interface class WalletMetadataChangeSource {
  Stream<void> get changes;
}

abstract interface class WalletMetadataRestoringContributor
    implements WalletMetadataContributor {
  @useResult
  Future<
    Result<WalletMetadataContributorApplySummary, WalletMetadataBackupFailure>
  >
  applyIntents({
    required List<WalletMetadataImportIntent> intents,
    required WalletMetadataApplyContext context,
  });
}
