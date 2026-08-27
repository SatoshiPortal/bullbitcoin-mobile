// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/data/wallet_metadata_snapshot_codec.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/data/wallet_metadata_snapshot_composition_repository_impl.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_apply.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_remote_head.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_inventory.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_record.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_recovery_plan.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/repositories/wallet_metadata_snapshot_composition_repository.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/wallet_metadata_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/wallet_metadata_contributor.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/wallet_metadata_section.dart';

DateTime _walletMetadataSystemNowUtc() => DateTime.now().toUtc();

final class WalletMetadataBackupImpl implements WalletMetadataBackup {
  final WalletMetadataSnapshotCodec _codec;
  final WalletMetadataSnapshotCompositionRepository _composition;
  final List<WalletMetadataContributor> _contributors;
  late final Map<String, WalletMetadataRestoringContributor> _restoring;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  final List<StreamSubscription<void>> _subscriptions = [];
  final DateTime Function() _nowUtc;
  bool _suppressChanges = false;
  bool _changesDuringSuppression = false;

  WalletMetadataBackupImpl({
    required List<WalletMetadataContributor> contributors,
    required List<WalletMetadataRestoringContributor> restoringContributors,
    WalletMetadataSnapshotCodec codec = const WalletMetadataSnapshotCodec(),
    WalletMetadataSnapshotCompositionRepository? composition,
    DateTime Function() nowUtc = _walletMetadataSystemNowUtc,
  }) : _contributors = List.unmodifiable(contributors),
       _codec = codec,
       _composition =
           composition ??
           const WalletMetadataSnapshotCompositionRepositoryImpl(),
       _nowUtc = nowUtc {
    if (_contributors.isEmpty ||
        _contributors.map((value) => value.recordType).toSet().length !=
            _contributors.length) {
      throw ArgumentError.value(contributors, 'contributors');
    }
    _restoring = {
      for (final contributor in restoringContributors)
        contributor.recordType: contributor,
    };
    if (_restoring.length != restoringContributors.length) {
      throw ArgumentError.value(restoringContributors, 'restoringContributors');
    }
    for (final contributor in _contributors) {
      if (contributor case final WalletMetadataChangeSource source) {
        _subscriptions.add(
          source.changes.listen((_) {
            if (_suppressChanges) {
              _changesDuringSuppression = true;
            } else if (!_changes.isClosed) {
              _changes.add(null);
            }
          }),
        );
      }
    }
  }

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<Result<WalletMetadataSnapshotInventory, WalletMetadataBackupFailure>>
  localInventory() async {
    final inventories = await _exportInventories();
    return switch (inventories) {
      Err(:final failure) => Err(failure),
      Ok(:final value) => _composition.compose(
        contributors: value,
        remoteHead: null,
      ),
    };
  }

  @override
  Future<Result<String?, WalletMetadataBackupFailure>> compose({
    required String parentFingerprint,
    required String? remotePayload,
  }) async {
    try {
      final remoteSnapshot = remotePayload == null
          ? null
          : _codec.decodeSnapshot(remotePayload);
      if (remoteSnapshot != null &&
          remoteSnapshot.parentFingerprint != parentFingerprint) {
        return const Err(WalletMetadataBackupKeyFailure());
      }

      final inventoryResult = await _exportInventories();
      final List<WalletMetadataContributorInventory> inventories;
      switch (inventoryResult) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          inventories = value;
      }

      final remoteHead = remoteSnapshot == null
          ? null
          : WalletMetadataRemoteHead(
              generation: 1,
              etag: _zeroHash,
              snapshot: remoteSnapshot,
              canonicalContentHash: _codec.contentHash(
                records: remoteSnapshot.records,
                sections: remoteSnapshot.sections,
              ),
            );
      final composed = _composition.compose(
        contributors: inventories,
        remoteHead: remoteHead,
      );
      final WalletMetadataSnapshotInventory inventory;
      switch (composed) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          inventory = value;
      }
      if (inventory.isEmpty && remoteSnapshot == null) return const Ok(null);
      if (remoteSnapshot != null &&
          remoteSnapshot.recordsHash == inventory.recordsHash &&
          _sameSections(remoteSnapshot.sections, inventory.sections)) {
        return Ok(remotePayload);
      }

      final now = _nowUtc().millisecondsSinceEpoch ~/ 1000;
      final createdAt = remoteSnapshot == null
          ? now
          : now > remoteSnapshot.createdAt
          ? now
          : remoteSnapshot.createdAt + 1;
      final snapshot = WalletMetadataSnapshot(
        parentFingerprint: parentFingerprint,
        revision: (remoteSnapshot?.revision ?? 0) + 1,
        createdAt: createdAt,
        recordsHash: inventory.recordsHash,
        recordCount: inventory.records.length,
        sections: inventory.sections,
        records: inventory.records,
      );
      return Ok(_codec.encodeSnapshot(snapshot));
    } on Exception {
      return const Err(WalletMetadataBackupEncodingFailure());
    }
  }

  Future<
    Result<
      List<WalletMetadataContributorInventory>,
      WalletMetadataBackupFailure
    >
  >
  _exportInventories() async {
    final inventories = <WalletMetadataContributorInventory>[];
    for (final contributor in _contributors) {
      switch (await contributor.exportRecords()) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          inventories.add(
            WalletMetadataContributorInventory(
              recordType: contributor.recordType,
              supportedVersions: contributor.supportedVersions,
              records: value,
            ),
          );
      }
    }
    return Ok(List.unmodifiable(inventories));
  }

  @override
  Future<Result<WalletMetadataRecoveryApplyResult, WalletMetadataBackupFailure>>
  recover({
    required String payload,
    required Set<String> createdWalletRefs,
    DateTime? deadline,
  }) async {
    _suppressChanges = true;
    try {
      _throwIfDeadlineReached(deadline);
      final snapshot = _codec.decodeSnapshot(payload);
      final planResult = _buildPlan(snapshot);
      final WalletMetadataRecoveryPlan plan;
      switch (planResult) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          plan = value;
      }
      final context = WalletMetadataApplyContext(
        createdWalletRefs: createdWalletRefs,
      );
      final outcomes = <WalletMetadataContributorApplyOutcome>[];
      for (final contributorPlan in plan.contributorPlans) {
        _throwIfDeadlineReached(deadline);
        final contributor = _restoring[contributorPlan.contributorType];
        if (contributor == null) {
          return const Err(WalletMetadataBackupEncodingFailure());
        }
        try {
          final applied = await contributor.applyIntents(
            intents: contributorPlan.intents,
            context: context,
          );
          _throwIfDeadlineReached(deadline);
          switch (applied) {
            case Err():
              outcomes.add(
                WalletMetadataContributorApplyOutcome.storageFailure(
                  contributorType: contributor.recordType,
                  intendedCount: contributorPlan.intents.length,
                ),
              );
            case Ok(:final value):
              outcomes.add(
                value.contributorType == contributor.recordType &&
                        value.intendedCount == contributorPlan.intents.length
                    ? WalletMetadataContributorApplyOutcome.success(value)
                    : WalletMetadataContributorApplyOutcome.storageFailure(
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
      final complete =
          plan.contributorPlans.length == _restoring.length &&
          plan.unsupportedRecords.isEmpty &&
          plan.unsupportedSections.isEmpty &&
          plan.invalidRecords.isEmpty &&
          outcomes.every(
            (outcome) =>
                !outcome.storageFailed &&
                outcome.localProjectionMatchesSnapshot,
          );
      return Ok(
        WalletMetadataRecoveryApplyResult(
          status: complete
              ? WalletMetadataRecoveryApplyStatus.complete
              : WalletMetadataRecoveryApplyStatus.incomplete,
          contributorOutcomes: outcomes,
          unsupportedRecordCount: plan.unsupportedRecords.length,
          unsupportedSectionCount: plan.unsupportedSections.length,
          invalidRecordCount: plan.invalidRecords.length,
        ),
      );
    } on Exception {
      return const Err(WalletMetadataBackupEncodingFailure());
    } finally {
      _suppressChanges = false;
      if (_changesDuringSuppression) {
        _changesDuringSuppression = false;
        if (!_changes.isClosed) _changes.add(null);
      }
    }
  }

  void _throwIfDeadlineReached(DateTime? deadline) {
    if (deadline != null && !_nowUtc().isBefore(deadline)) {
      throw TimeoutException('wallet metadata recovery deadline');
    }
  }

  Result<WalletMetadataRecoveryPlan, WalletMetadataBackupFailure> _buildPlan(
    WalletMetadataSnapshot snapshot,
  ) {
    final contributorsByType = {
      for (final contributor in _contributors)
        contributor.recordType: contributor,
    };
    final intentsByType = <String, List<WalletMetadataImportIntent>>{};
    final invalidRecords = <WalletMetadataInvalidRecord>[];
    final unsupportedRecords = <WalletMetadataRecord>[];
    for (final record in snapshot.records) {
      final contributor = contributorsByType[record.type];
      if (contributor == null ||
          !contributor.supportedVersions.contains(record.version)) {
        unsupportedRecords.add(record);
        continue;
      }
      final validation = contributor.validateRecord(record);
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
    final unsupportedSections = snapshot.sections
        .where((section) {
          final contributor = contributorsByType[section.type];
          return contributor == null ||
              section.versions.any(
                (version) => !contributor.supportedVersions.contains(version),
              );
        })
        .toList(growable: false);
    final plans = snapshot.sections
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
      final head = WalletMetadataRemoteHead(
        generation: 1,
        etag: _zeroHash,
        snapshot: snapshot,
        canonicalContentHash: _codec.contentHash(
          records: snapshot.records,
          sections: snapshot.sections,
        ),
      );
      return Ok(
        WalletMetadataRecoveryPlan(
          selectedHead: head,
          contributorPlans: plans,
          unsupportedRecords: unsupportedRecords,
          unsupportedSections: unsupportedSections,
          invalidRecords: invalidRecords,
        ),
      );
    } on ArgumentError {
      return const Err(WalletMetadataBackupEncodingFailure());
    }
  }

  @override
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _changes.close();
  }
}

const _zeroHash =
    '0000000000000000000000000000000000000000000000000000000000000000';

bool _sameSections(
  List<WalletMetadataSection> left,
  List<WalletMetadataSection> right,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    final a = left[index];
    final b = right[index];
    if (a.type != b.type ||
        a.recordCount != b.recordCount ||
        a.recordsHash != b.recordsHash ||
        a.versions.length != b.versions.length) {
      return false;
    }
    for (var version = 0; version < a.versions.length; version++) {
      if (a.versions[version] != b.versions[version]) return false;
    }
  }
  return true;
}
