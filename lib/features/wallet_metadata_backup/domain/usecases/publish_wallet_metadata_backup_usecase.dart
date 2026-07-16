import 'dart:math';

import 'package:bb_mobile/core/utils/clock.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_backup_state.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_encrypted_snapshot.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_inventory.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_key_material.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_publish_outcome.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_remote_head.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_snapshot.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/repositories/wallet_metadata_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/repositories/wallet_metadata_remote_repository.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/repositories/wallet_metadata_snapshot_composition_repository.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_snapshot_cryptor.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_failure.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_limits.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_contributor.dart';
import 'package:meta/meta.dart';

final class PublishWalletMetadataBackupUsecase {
  final WalletMetadataBackupStateRepository _stateRepository;
  final WalletMetadataRemoteRepository _remoteRepository;
  final WalletMetadataSnapshotCompositionRepository _compositionRepository;
  final WalletMetadataSnapshotCryptor _snapshotCryptor;
  final List<WalletMetadataContributor> _contributors;
  final Clock _clock;

  PublishWalletMetadataBackupUsecase({
    required this._stateRepository,
    required this._remoteRepository,
    required this._compositionRepository,
    required WalletMetadataSnapshotCryptor snapshotCryptor,
    required List<WalletMetadataContributor> contributors,
    this._clock = const SystemClock(),
    // ignore: prefer_initializing_formals
  }) : _snapshotCryptor = snapshotCryptor,
       _contributors = List.unmodifiable(contributors) {
    if (_contributors.isEmpty ||
        _contributors.map((value) => value.recordType).toSet().length !=
            _contributors.length) {
      throw ArgumentError.value(contributors, 'contributors');
    }
  }

  @useResult
  Future<Result<WalletMetadataPublishOutcome, WalletMetadataBackupFailure>>
  execute({required WalletMetadataKeyMaterial keyMaterial}) async {
    final initialResult = await _stateRepository.fetch();
    final WalletMetadataBackupState initial;
    switch (initialResult) {
      case Ok(:final value):
        initial = value;
      case Err(:final failure):
        return Err(failure);
    }
    if (initial.unsupportedNewerEnvelope != null) {
      return const Err(WalletMetadataBackupUpdateRequiredFailure());
    }
    if (!initial.canAttemptStore) {
      return const Ok(
        WalletMetadataPublishOutcome(
          status: WalletMetadataPublishStatus.notReady,
        ),
      );
    }

    final now = _clock.nowSecs();
    if (now < 0 || now > WalletMetadataBackupLimits.maxSignedInt64) {
      return const Err(WalletMetadataBackupClockFailure());
    }
    final attempted = await _stateRepository.update(
      (state) =>
          state.canAttemptStore ? state.recordStoreAttempted(now) : state,
    );
    final WalletMetadataBackupState publicationState;
    switch (attempted) {
      case Ok(:final value):
        publicationState = value;
      case Err(:final failure):
        return Err(failure);
    }
    if (!publicationState.canAttemptStore) {
      return const Ok(
        WalletMetadataPublishOutcome(
          status: WalletMetadataPublishStatus.notReady,
        ),
      );
    }
    final dirtyRevision = publicationState.dirtyRevision;
    final inventoriesResult = await _exportContributors();
    final List<WalletMetadataContributorInventory> inventories;
    switch (inventoriesResult) {
      case Ok(:final value):
        inventories = value;
      case Err(:final failure):
        return Err(failure);
    }

    for (var attempt = 0; attempt < 2; attempt++) {
      final fetched = await _remoteRepository.fetch(keyMaterial: keyMaterial);
      final WalletMetadataRemoteFetchResult remote;
      switch (fetched) {
        case Ok(:final value):
          remote = value;
        case Err(:final failure):
          return Err(failure);
      }
      if (remote case WalletMetadataRemoteUnsupported(
        :final generation,
        :final etag,
        :final envelopeVersion,
      )) {
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
        return const Err(WalletMetadataBackupUpdateRequiredFailure());
      }

      final remoteHead = switch (remote) {
        WalletMetadataRemotePresent(:final head) => head,
        _ => null,
      };
      final absentGeneration = switch (remote) {
        WalletMetadataRemoteAbsent(:final generation) => generation,
        _ => 0,
      };
      final absentEtag = switch (remote) {
        WalletMetadataRemoteAbsent(:final etag) => etag,
        _ => null,
      };
      final composed = _compositionRepository.compose(
        contributors: inventories,
        remoteHead: remoteHead,
      );
      final WalletMetadataSnapshotInventory inventory;
      switch (composed) {
        case Ok(:final value):
          inventory = value;
        case Err(:final failure):
          return Err(failure);
      }

      if (inventory.isEmpty &&
          remoteHead == null &&
          publicationState.verifiedHead == null) {
        final clean = await _stateRepository.update(
          (state) =>
              state.recordNoStoreNeeded(expectedDirtyRevision: dirtyRevision),
        );
        if (clean case Err(:final failure)) return Err(failure);
        return const Ok(
          WalletMetadataPublishOutcome(
            status: WalletMetadataPublishStatus.initialEmpty,
          ),
        );
      }

      if (remoteHead != null &&
          remoteHead.snapshot.recordsHash == inventory.recordsHash &&
          _sameSections(remoteHead.snapshot.sections, inventory.sections)) {
        final verified = await _recordVerified(
          remoteGeneration: remoteHead.generation,
          remoteEtag: remoteHead.etag,
          snapshotRevision: remoteHead.snapshot.revision,
          contentHash: inventory.canonicalContentHash,
          verifiedAt: now,
          dirtyRevision: dirtyRevision,
        );
        if (verified case Err(:final failure)) return Err(failure);
        return Ok(
          WalletMetadataPublishOutcome(
            status: WalletMetadataPublishStatus.unchanged,
            remoteGeneration: remoteHead.generation,
            remoteEtag: remoteHead.etag,
          ),
        );
      }

      final baseRevision = max(
        publicationState.verifiedHead?.snapshotRevision ?? 0,
        remoteHead?.snapshot.revision ?? 0,
      );
      if (baseRevision >= WalletMetadataBackupLimits.maxSignedInt64) {
        return const Err(WalletMetadataBackupClockFailure());
      }
      final createdAt = max(now, (remoteHead?.snapshot.createdAt ?? -1) + 1);
      final built = _snapshotCryptor.build(
        keyMaterial: keyMaterial,
        revision: baseRevision + 1,
        createdAt: createdAt,
        records: inventory.records,
        sections: inventory.sections,
      );
      final WalletMetadataEncryptedSnapshot snapshot;
      switch (built) {
        case Ok(:final value):
          snapshot = value;
        case Err(:final failure):
          return Err(failure);
      }
      final stored = await _remoteRepository.store(
        keyMaterial: keyMaterial,
        snapshot: snapshot,
        generation: (remoteHead?.generation ?? absentGeneration) + 1,
        expectedEtag: remoteHead?.etag ?? absentEtag,
      );
      switch (stored) {
        case Err(failure: WalletMetadataBackupConflictFailure())
            when attempt == 0:
          continue;
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          final verified = await _recordVerified(
            remoteGeneration: value.generation,
            remoteEtag: value.etag,
            snapshotRevision: snapshot.plaintext.revision,
            contentHash: inventory.canonicalContentHash,
            verifiedAt: now,
            dirtyRevision: dirtyRevision,
          );
          if (verified case Err(:final failure)) return Err(failure);
          return Ok(
            WalletMetadataPublishOutcome(
              status: WalletMetadataPublishStatus.stored,
              remoteGeneration: value.generation,
              remoteEtag: value.etag,
            ),
          );
      }
    }
    return const Err(WalletMetadataBackupConflictFailure());
  }

  Future<
    Result<
      List<WalletMetadataContributorInventory>,
      WalletMetadataBackupFailure
    >
  >
  _exportContributors() async {
    final inventories = <WalletMetadataContributorInventory>[];
    for (final contributor in _contributors) {
      final exported = await contributor.exportRecords();
      switch (exported) {
        case Ok(:final value):
          inventories.add(
            WalletMetadataContributorInventory(
              recordType: contributor.recordType,
              supportedVersions: contributor.supportedVersions,
              records: value,
            ),
          );
        case Err(:final failure):
          return Err(failure);
      }
    }
    return Ok(inventories);
  }

  Future<Result<WalletMetadataBackupState, WalletMetadataBackupFailure>>
  _recordVerified({
    required int remoteGeneration,
    required String remoteEtag,
    required int snapshotRevision,
    required String contentHash,
    required int verifiedAt,
    required int dirtyRevision,
  }) {
    return _stateRepository.update(
      (state) => state.recordVerifiedHead(
        head: WalletMetadataBackupVerifiedHead(
          remoteGeneration: remoteGeneration,
          remoteEtag: remoteEtag,
          snapshotRevision: snapshotRevision,
          canonicalContentHash: contentHash,
          verifiedAt: verifiedAt,
        ),
        expectedDirtyRevision: dirtyRevision,
      ),
    );
  }
}

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
        !_sameInts(a.versions, b.versions)) {
      return false;
    }
  }
  return true;
}

bool _sameInts(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
