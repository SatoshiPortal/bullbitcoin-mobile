import 'package:bb_mobile/core/utils/clock.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_apply.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_backup_state.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_key_material.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_recovery_plan.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_record.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_remote_head.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_snapshot.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/repositories/wallet_metadata_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/repositories/wallet_metadata_remote_repository.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_failure.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_limits.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_key_material_port.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_contributor.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_json.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_publication_guard.dart';
import 'package:meta/meta.dart';

final class ApplyWalletMetadataRecoveryPlanUsecase {
  final WalletMetadataBackupStateRepository _stateRepository;
  final WalletMetadataRemoteRepository _remoteRepository;
  final Map<String, WalletMetadataRestoringContributor> _contributorsByType;
  final WalletMetadataPublicationGuard _publicationGuard;
  final WalletMetadataKeyMaterialPort _keyMaterialPort;
  final Clock _clock;

  ApplyWalletMetadataRecoveryPlanUsecase(
    this._keyMaterialPort, {
    required this._stateRepository,
    required WalletMetadataRemoteRepository remoteRepository,
    required List<WalletMetadataRestoringContributor> contributors,
    WalletMetadataPublicationGuard? publicationGuard,
    this._clock = const SystemClock(),
    // ignore: prefer_initializing_formals
  }) : _remoteRepository = remoteRepository,
       _contributorsByType = {
         for (final contributor in contributors)
           contributor.recordType: contributor,
       },
       _publicationGuard =
           publicationGuard ?? WalletMetadataPublicationGuard() {
    if (contributors.isEmpty ||
        _contributorsByType.length != contributors.length) {
      throw ArgumentError.value(contributors, 'contributors');
    }
  }

  @useResult
  Future<Result<WalletMetadataRecoveryApplyResult, WalletMetadataBackupFailure>>
  execute({
    required WalletMetadataRecoveryPlan plan,
    required Set<String> createdWalletRefs,
  }) {
    return _publicationGuard.suppressApplyChangesWhile(
      () => _execute(plan: plan, createdWalletRefs: createdWalletRefs),
    );
  }

  Future<Result<WalletMetadataRecoveryApplyResult, WalletMetadataBackupFailure>>
  _execute({
    required WalletMetadataRecoveryPlan plan,
    required Set<String> createdWalletRefs,
  }) async {
    final preflightFailure = _preflight(plan);
    if (preflightFailure != null) return Err(preflightFailure);

    final keyMaterialResult = await _keyMaterialPort.deriveLocal();
    final WalletMetadataKeyMaterial keyMaterial;
    switch (keyMaterialResult) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        keyMaterial = value;
        if (value.parentFingerprint !=
            plan.selectedHead.snapshot.parentFingerprint) {
          return const Err(WalletMetadataBackupKeyFailure());
        }
    }

    final refreshed = await _remoteRepository.fetch(keyMaterial: keyMaterial);
    switch (refreshed) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: WalletMetadataRemotePresent(:final head)):
        final selected = plan.selectedHead;
        if (head.generation != selected.generation ||
            head.etag != selected.etag ||
            head.canonicalContentHash != selected.canonicalContentHash) {
          return const Err(WalletMetadataBackupConflictFailure());
        }
      case Ok():
        return const Err(WalletMetadataBackupConflictFailure());
    }

    final now = _clock.nowSecs();
    if (now < 0 || now > WalletMetadataBackupLimits.maxSignedInt64) {
      return const Err(WalletMetadataBackupClockFailure());
    }
    final selected = plan.selectedHead;
    final startedBlock = WalletMetadataBackupRecoveryBlock(
      reason: WalletMetadataRecoveryBlockReason.applyInProgress,
      remoteGeneration: selected.generation,
      remoteEtag: selected.etag,
      snapshotRevision: selected.snapshot.revision,
      observedAt: now,
    );
    final started = await _stateRepository.update(
      (state) => state.recordRecoveryApplyStarted(startedBlock),
    );
    final WalletMetadataBackupState applyState;
    switch (started) {
      case Ok(:final value):
        applyState = value;
      case Err(:final failure):
        return Err(failure);
    }

    final context = WalletMetadataApplyContext(
      createdWalletRefs: createdWalletRefs,
    );
    final outcomes = <WalletMetadataContributorApplyOutcome>[];
    for (final contributorPlan in plan.contributorPlans) {
      final contributor = _contributorsByType[contributorPlan.contributorType]!;
      try {
        final result = await contributor.applyIntents(
          intents: contributorPlan.intents,
          context: context,
        );
        switch (result) {
          case Ok(:final value):
            if (value.contributorType != contributor.recordType ||
                value.intendedCount != contributorPlan.intents.length) {
              outcomes.add(
                WalletMetadataContributorApplyOutcome.storageFailure(
                  contributorType: contributor.recordType,
                  intendedCount: contributorPlan.intents.length,
                ),
              );
            } else {
              outcomes.add(
                WalletMetadataContributorApplyOutcome.success(value),
              );
            }
          case Err():
            outcomes.add(
              WalletMetadataContributorApplyOutcome.storageFailure(
                contributorType: contributor.recordType,
                intendedCount: contributorPlan.intents.length,
              ),
            );
        }
      } on Exception {
        outcomes.add(
          WalletMetadataContributorApplyOutcome.storageFailure(
            contributorType: contributor.recordType,
            intendedCount: contributorPlan.intents.length,
          ),
        );
      }
    }

    final allContributorTypesPlanned =
        plan.contributorPlans.length == _contributorsByType.length;
    final complete =
        allContributorTypesPlanned &&
        plan.unsupportedRecords.isEmpty &&
        plan.unsupportedSections.isEmpty &&
        plan.invalidRecords.isEmpty &&
        outcomes.every(
          (outcome) =>
              !outcome.storageFailed && outcome.localProjectionMatchesSnapshot,
        );
    final status = complete
        ? WalletMetadataRecoveryApplyStatus.complete
        : WalletMetadataRecoveryApplyStatus.incomplete;

    final finalStateResult = await _stateRepository.update((state) {
      if (status == WalletMetadataRecoveryApplyStatus.complete) {
        return state.recordRecoveryAppliedClean(
          head: WalletMetadataBackupVerifiedHead(
            remoteGeneration: selected.generation,
            remoteEtag: selected.etag,
            snapshotRevision: selected.snapshot.revision,
            canonicalContentHash: selected.canonicalContentHash,
            verifiedAt: now,
          ),
          expectedDirtyRevision: applyState.dirtyRevision,
        );
      }
      return state.recordRecoveryApplyBlocked(
        startedBlock.withReason(
          WalletMetadataRecoveryBlockReason.incompleteApply,
        ),
      );
    });
    final WalletMetadataBackupState finalState;
    switch (finalStateResult) {
      case Ok(:final value):
        finalState = value;
      case Err(:final failure):
        return Err(failure);
    }
    final effectiveStatus =
        status == WalletMetadataRecoveryApplyStatus.complete &&
            finalState.recoveryBlock != null
        ? WalletMetadataRecoveryApplyStatus.incomplete
        : status;

    return Ok(
      WalletMetadataRecoveryApplyResult(
        status: effectiveStatus,
        contributorOutcomes: outcomes,
        unsupportedRecordCount: plan.unsupportedRecords.length,
        unsupportedSectionCount: plan.unsupportedSections.length,
        invalidRecordCount: plan.invalidRecords.length,
      ),
    );
  }

  WalletMetadataBackupFailure? _preflight(WalletMetadataRecoveryPlan plan) {
    final selectedRecords = {
      for (final record in plan.selectedHead.records) record.identity: record,
    };
    if (selectedRecords.length != plan.selectedHead.records.length) {
      return const WalletMetadataBackupEncodingFailure();
    }

    final expectedIntents = <String, Map<String, WalletMetadataImportIntent>>{};
    final expectedUnsupportedRecords = <String, WalletMetadataRecord>{};
    final expectedInvalidRecords =
        <
          ({
            String type,
            int version,
            WalletMetadataRecordInvalidReason reason,
          }),
          int
        >{};
    for (final record in plan.selectedHead.records) {
      final contributor = _contributorsByType[record.type];
      if (contributor == null ||
          !contributor.supportedVersions.contains(record.version)) {
        expectedUnsupportedRecords[record.identity] = record;
        continue;
      }
      final WalletMetadataRecordValidation validation;
      try {
        validation = contributor.validateRecord(record);
      } on Exception {
        return WalletMetadataBackupContributorFailure(contributor.recordType);
      }
      switch (validation) {
        case WalletMetadataRecordValid(:final intent):
          expectedIntents.putIfAbsent(record.type, () => {})[record.identity] =
              intent;
        case WalletMetadataRecordInvalid(:final reason):
          final key = (
            type: record.type,
            version: record.version,
            reason: reason,
          );
          expectedInvalidRecords[key] = (expectedInvalidRecords[key] ?? 0) + 1;
      }
    }

    if (!_sameRecordMap(expectedUnsupportedRecords, plan.unsupportedRecords) ||
        !_sameInvalidRecordCounts(
          expectedInvalidRecords,
          plan.invalidRecords,
        ) ||
        !_sameUnsupportedSections(plan)) {
      return const WalletMetadataBackupEncodingFailure();
    }

    final expectedSectionVersions = <String, List<int>>{};
    for (final section in plan.selectedHead.snapshot.sections) {
      final contributor = _contributorsByType[section.type];
      if (contributor == null) continue;
      final versions = section.versions
          .where(contributor.supportedVersions.contains)
          .toList(growable: false);
      if (versions.isNotEmpty) expectedSectionVersions[section.type] = versions;
    }
    if (expectedSectionVersions.length != plan.contributorPlans.length) {
      return const WalletMetadataBackupEncodingFailure();
    }

    for (final contributorPlan in plan.contributorPlans) {
      final contributor = _contributorsByType[contributorPlan.contributorType];
      final expectedVersions =
          expectedSectionVersions[contributorPlan.contributorType];
      if (contributor == null ||
          expectedVersions == null ||
          !_sameInts(expectedVersions, contributorPlan.sectionVersions)) {
        return const WalletMetadataBackupEncodingFailure();
      }
      final identities = <String>{};
      for (final plannedIntent in contributorPlan.intents) {
        final plannedRecord = plannedIntent.record;
        final selectedRecord = selectedRecords[plannedRecord.identity];
        if (!identities.add(plannedRecord.identity) ||
            selectedRecord == null ||
            !_sameRecord(selectedRecord, plannedRecord)) {
          return WalletMetadataBackupContributorFailure(contributor.recordType);
        }
        final validation = contributor.validateRecord(plannedRecord);
        if (validation is! WalletMetadataRecordValid ||
            validation.intent.recordIdentity != plannedIntent.recordIdentity ||
            !_sameRecord(validation.intent.record, plannedRecord)) {
          return WalletMetadataBackupContributorFailure(contributor.recordType);
        }
      }
      final expected = expectedIntents[contributor.recordType] ?? const {};
      if (identities.length != expected.length ||
          !identities.containsAll(expected.keys)) {
        return WalletMetadataBackupContributorFailure(contributor.recordType);
      }
    }
    return null;
  }

  bool _sameUnsupportedSections(WalletMetadataRecoveryPlan plan) {
    final expected = <String, WalletMetadataSection>{};
    for (final section in plan.selectedHead.snapshot.sections) {
      final contributor = _contributorsByType[section.type];
      if (contributor == null ||
          section.versions.any(
            (version) => !contributor.supportedVersions.contains(version),
          )) {
        expected[section.type] = section;
      }
    }
    if (expected.length != plan.unsupportedSections.length) return false;
    for (final section in plan.unsupportedSections) {
      final selected = expected[section.type];
      if (selected == null || !_sameSection(selected, section)) return false;
    }
    return true;
  }
}

bool _sameRecord(WalletMetadataRecord left, WalletMetadataRecord right) {
  return left.identity == right.identity &&
      walletMetadataCanonicalJsonEncode(left.payload) ==
          walletMetadataCanonicalJsonEncode(right.payload);
}

bool _sameRecordMap(
  Map<String, WalletMetadataRecord> expected,
  List<WalletMetadataRecord> actual,
) {
  if (expected.length != actual.length) return false;
  final identities = <String>{};
  for (final record in actual) {
    final selected = expected[record.identity];
    if (!identities.add(record.identity) ||
        selected == null ||
        !_sameRecord(selected, record)) {
      return false;
    }
  }
  return true;
}

bool _sameInvalidRecordCounts(
  Map<
    ({String type, int version, WalletMetadataRecordInvalidReason reason}),
    int
  >
  expected,
  List<WalletMetadataInvalidRecord> actual,
) {
  final actualCounts =
      <
        ({String type, int version, WalletMetadataRecordInvalidReason reason}),
        int
      >{};
  for (final record in actual) {
    final key = (
      type: record.recordType,
      version: record.recordVersion,
      reason: record.reason,
    );
    actualCounts[key] = (actualCounts[key] ?? 0) + 1;
  }
  if (expected.length != actualCounts.length) return false;
  return expected.entries.every(
    (entry) => actualCounts[entry.key] == entry.value,
  );
}

bool _sameSection(WalletMetadataSection left, WalletMetadataSection right) {
  return left.type == right.type &&
      _sameInts(left.versions, right.versions) &&
      left.recordCount == right.recordCount &&
      left.recordsHash == right.recordsHash;
}

bool _sameInts(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
