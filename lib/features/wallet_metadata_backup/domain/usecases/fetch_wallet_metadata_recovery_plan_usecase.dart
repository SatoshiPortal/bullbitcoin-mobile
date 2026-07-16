import 'package:bb_mobile/core/utils/clock.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_backup_state.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_key_material.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_recovery_plan.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_record.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_remote_head.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/repositories/wallet_metadata_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/repositories/wallet_metadata_remote_repository.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_failure.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_limits.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_contributor.dart';
import 'package:meta/meta.dart';

final class FetchWalletMetadataRecoveryPlanUsecase {
  final WalletMetadataBackupStateRepository _stateRepository;
  final WalletMetadataRemoteRepository _remoteRepository;
  final List<WalletMetadataContributor> _contributors;
  final Clock _clock;

  FetchWalletMetadataRecoveryPlanUsecase({
    required this._stateRepository,
    required this._remoteRepository,
    required List<WalletMetadataContributor> contributors,
    this._clock = const SystemClock(),
  }) : _contributors = List.unmodifiable(contributors) {
    if (_contributors.isEmpty ||
        _contributors.map((value) => value.recordType).toSet().length !=
            _contributors.length) {
      throw ArgumentError.value(contributors, 'contributors');
    }
  }

  @useResult
  Future<Result<WalletMetadataRecoveryResult, WalletMetadataBackupFailure>>
  execute({required WalletMetadataKeyMaterial keyMaterial}) async {
    final fetched = await _remoteRepository.fetch(keyMaterial: keyMaterial);
    final WalletMetadataRemoteFetchResult remote;
    switch (fetched) {
      case Ok(:final value):
        remote = value;
      case Err(failure: WalletMetadataBackupRemoteFailure()):
        return const Ok(WalletMetadataRecoveryResult.remoteUnavailable());
      case Err(:final failure):
        return Err(failure);
    }
    switch (remote) {
      case WalletMetadataRemoteAbsent():
        return const Ok(WalletMetadataRecoveryResult.noSnapshotFound());
      case WalletMetadataRemoteUnsupported(
        :final generation,
        :final etag,
        :final envelopeVersion,
      ):
        final now = _clock.nowSecs();
        if (now < 0 || now > WalletMetadataBackupLimits.maxSignedInt64) {
          return const Err(WalletMetadataBackupClockFailure());
        }
        final persisted = await _stateRepository.update(
          (state) => state.recordUnsupportedNewerEnvelope(
            WalletMetadataBackupUnsupportedEnvelope(
              remoteGeneration: generation,
              remoteEtag: etag,
              envelopeVersion: envelopeVersion,
              observedAt: now,
            ),
          ),
        );
        if (persisted case Err(:final failure)) return Err(failure);
        return const Ok(
          WalletMetadataRecoveryResult.unsupportedNewerEnvelope(),
        );
      case WalletMetadataRemotePresent(:final head):
        return _buildPlan(head).map(WalletMetadataRecoveryResult.ready);
    }
  }

  Result<WalletMetadataRecoveryPlan, WalletMetadataBackupFailure> _buildPlan(
    WalletMetadataRemoteHead head,
  ) {
    final contributorsByType = {
      for (final contributor in _contributors)
        contributor.recordType: contributor,
    };
    final intentsByType = <String, List<WalletMetadataImportIntent>>{};
    final invalidRecords = <WalletMetadataInvalidRecord>[];
    final unsupportedRecords = <WalletMetadataRecord>[];
    for (final record in head.snapshot.records) {
      final contributor = contributorsByType[record.type];
      if (contributor == null ||
          !contributor.supportedVersions.contains(record.version)) {
        unsupportedRecords.add(record);
        continue;
      }
      final WalletMetadataRecordValidation validation;
      try {
        validation = contributor.validateRecord(record);
      } on Exception {
        return Err(WalletMetadataBackupContributorFailure(record.type));
      }
      switch (validation) {
        case WalletMetadataRecordValid(:final intent):
          intentsByType.putIfAbsent(record.type, () => []).add(intent);
        case WalletMetadataRecordInvalid(:final reason):
          invalidRecords.add(
            WalletMetadataInvalidRecord(
              recordType: record.type,
              recordVersion: record.version,
              reason: reason,
            ),
          );
      }
    }
    final unsupportedSections = head.snapshot.sections
        .where((section) {
          final contributor = contributorsByType[section.type];
          return contributor == null ||
              section.versions.any(
                (version) => !contributor.supportedVersions.contains(version),
              );
        })
        .toList(growable: false);
    final contributorPlans = head.snapshot.sections
        .map((section) {
          final contributor = contributorsByType[section.type];
          if (contributor == null) return null;
          final versions = section.versions
              .where(contributor.supportedVersions.contains)
              .toList(growable: false);
          if (versions.isEmpty) return null;
          return WalletMetadataContributorImportPlan(
            contributorType: section.type,
            sectionVersions: versions,
            intents: intentsByType[section.type] ?? const [],
          );
        })
        .nonNulls
        .toList(growable: false);
    try {
      return Ok(
        WalletMetadataRecoveryPlan(
          selectedHead: head,
          contributorPlans: contributorPlans,
          unsupportedRecords: unsupportedRecords,
          unsupportedSections: unsupportedSections,
          invalidRecords: invalidRecords,
        ),
      );
    } on ArgumentError {
      return const Err(WalletMetadataBackupEncodingFailure());
    }
  }
}
