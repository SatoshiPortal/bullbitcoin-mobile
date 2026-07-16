import 'package:bb_mobile/core/utils/clock.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/data/wallet_metadata_snapshot_codec.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_apply.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_key_material.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_backup_state.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_recovery_plan.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_record.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_remote_head.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_snapshot.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/repositories/wallet_metadata_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/repositories/wallet_metadata_remote_repository.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/usecases/apply_wallet_metadata_recovery_plan_usecase.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/usecases/fetch_wallet_metadata_recovery_plan_usecase.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_failure.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_key_material_port.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_contributor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Bullnym outage is a non-blocking recovery result', () async {
    final usecase = FetchWalletMetadataRecoveryPlanUsecase(
      stateRepository: _StateRepository(),
      remoteRepository: _RemoteRepository(
        const Err(WalletMetadataBackupRemoteFailure()),
      ),
      contributors: [_Contributor()],
      clock: const _Clock(),
    );

    final result = await usecase.execute(keyMaterial: _keyMaterial);

    expect(_ok(result).status, WalletMetadataRecoveryStatus.remoteUnavailable);
  });

  test('fetches, validates and applies the current Bullnym snapshot', () async {
    final state = _StateRepository();
    final head = _head();
    final contributor = _Contributor();
    final fetched = await FetchWalletMetadataRecoveryPlanUsecase(
      stateRepository: state,
      remoteRepository: _RemoteRepository(
        Ok(WalletMetadataRemotePresent(head)),
      ),
      contributors: [contributor],
      clock: const _Clock(),
    ).execute(keyMaterial: _keyMaterial);
    final plan = _ok(fetched).plan!;

    final applied = await ApplyWalletMetadataRecoveryPlanUsecase(
      const _RootPort(),
      stateRepository: state,
      remoteRepository: _RemoteRepository(
        Ok(WalletMetadataRemotePresent(head)),
      ),
      contributors: [contributor],
      clock: const _Clock(),
    ).execute(plan: plan, createdWalletRefs: {'wallet-1'});

    expect(_ok(applied).status, WalletMetadataRecoveryApplyStatus.complete);
    expect(contributor.applied, hasLength(1));
    expect(state.state.dirty, isFalse);
    expect(state.state.verifiedHead?.remoteEtag, head.etag);
  });

  test('rejects a recovery plan when Bullnym changed before apply', () async {
    final state = _StateRepository();
    final selected = _head();
    final contributor = _Contributor();
    final fetched = await FetchWalletMetadataRecoveryPlanUsecase(
      stateRepository: state,
      remoteRepository: _RemoteRepository(
        Ok(WalletMetadataRemotePresent(selected)),
      ),
      contributors: [contributor],
      clock: const _Clock(),
    ).execute(keyMaterial: _keyMaterial);
    final changed = WalletMetadataRemoteHead(
      generation: selected.generation + 1,
      etag: 'b'.padLeft(64, 'b'),
      snapshot: selected.snapshot,
      canonicalContentHash: selected.canonicalContentHash,
    );

    final applied = await ApplyWalletMetadataRecoveryPlanUsecase(
      const _RootPort(),
      stateRepository: state,
      remoteRepository: _RemoteRepository(
        Ok(WalletMetadataRemotePresent(changed)),
      ),
      contributors: [contributor],
      clock: const _Clock(),
    ).execute(plan: _ok(fetched).plan!, createdWalletRefs: {'wallet-1'});

    expect(applied, isA<Err>());
    expect(
      (applied as Err).failure,
      isA<WalletMetadataBackupConflictFailure>(),
    );
    expect(contributor.applied, isEmpty);
    expect(state.state.recoveryBlock, isNull);
  });
}

final class _RemoteRepository implements WalletMetadataRemoteRepository {
  final Result<WalletMetadataRemoteFetchResult, WalletMetadataBackupFailure>
  result;
  const _RemoteRepository(this.result);

  @override
  Future<Result<WalletMetadataRemoteFetchResult, WalletMetadataBackupFailure>>
  fetch({required WalletMetadataKeyMaterial keyMaterial}) async => result;

  @override
  Future<Result<WalletMetadataRemoteStoreReceipt, WalletMetadataBackupFailure>>
  store({
    required WalletMetadataKeyMaterial keyMaterial,
    required dynamic snapshot,
    required int generation,
    required String? expectedEtag,
  }) => throw UnimplementedError();

  @override
  Future<Result<void, WalletMetadataBackupFailure>> delete({
    required WalletMetadataKeyMaterial keyMaterial,
  }) => throw UnimplementedError();
}

final class _StateRepository implements WalletMetadataBackupStateRepository {
  WalletMetadataBackupState state = WalletMetadataBackupState.initial;
  @override
  Future<Result<WalletMetadataBackupState, WalletMetadataBackupFailure>>
  fetch() async => Ok(state);
  @override
  Future<Result<WalletMetadataBackupState, WalletMetadataBackupFailure>> update(
    WalletMetadataBackupStateUpdate update,
  ) async {
    state = update(state);
    return Ok(state);
  }
}

final class _Contributor implements WalletMetadataRestoringContributor {
  final List<WalletMetadataImportIntent> applied = [];
  @override
  String get recordType => 'owned';
  @override
  Set<int> get supportedVersions => const {1};
  @override
  Future<Result<List<WalletMetadataRecord>, WalletMetadataBackupFailure>>
  exportRecords() async => Ok([_record]);
  @override
  WalletMetadataRecordValidation validateRecord(WalletMetadataRecord record) {
    if (record.type != recordType || record.version != 1) {
      return const WalletMetadataRecordInvalid(
        WalletMetadataRecordInvalidReason.unsupportedTypeOrVersion,
      );
    }
    return WalletMetadataRecordValid(
      WalletMetadataImportIntent(contributorType: recordType, record: record),
    );
  }

  @override
  Future<
    Result<WalletMetadataContributorApplySummary, WalletMetadataBackupFailure>
  >
  applyIntents({
    required List<WalletMetadataImportIntent> intents,
    required WalletMetadataApplyContext context,
  }) async {
    applied.addAll(intents);
    return Ok(
      WalletMetadataContributorApplySummary(
        contributorType: recordType,
        intendedCount: intents.length,
        restoredCount: intents.length,
        alreadyPresentCount: 0,
        preservedLocalConflictCount: 0,
        deferredMissingWalletCount: 0,
        localProjectionMatchesSnapshot: true,
      ),
    );
  }
}

final class _RootPort implements WalletMetadataKeyMaterialPort {
  const _RootPort();
  @override
  Future<Result<WalletMetadataKeyMaterial, WalletMetadataBackupFailure>>
  deriveLocal() async => Ok(
    WalletMetadataKeyMaterial(
      xprvBase58: 'xprv',
      parentFingerprint: '627ef3a6',
    ),
  );
}

WalletMetadataRemoteHead _head() {
  const codec = WalletMetadataSnapshotCodec();
  final section = WalletMetadataSection(
    type: 'owned',
    versions: const [1],
    recordCount: 1,
    recordsHash: codec.recordsHash([_record]),
  );
  final snapshot = WalletMetadataSnapshot(
    parentFingerprint: '627ef3a6',
    revision: 3,
    createdAt: 10,
    recordsHash: codec.recordsHash([_record]),
    recordCount: 1,
    sections: [section],
    records: [_record],
  );
  return WalletMetadataRemoteHead(
    generation: 4,
    etag: 'a'.padLeft(64, 'a'),
    snapshot: snapshot,
    canonicalContentHash: codec.contentHash(
      records: [_record],
      sections: [section],
    ),
  );
}

final _record = WalletMetadataRecord(
  type: 'owned',
  version: 1,
  scope: const {'wallet': 'wallet-1'},
  recordId: 'record-1',
  payload: const {'label': 'Recovered'},
);

final _keyMaterial = WalletMetadataKeyMaterial(
  xprvBase58: 'xprv',
  parentFingerprint: '627ef3a6',
);

final class _Clock implements Clock {
  const _Clock();
  @override
  DateTime nowUtc() => DateTime.fromMillisecondsSinceEpoch(10000, isUtc: true);
}

T _ok<T>(Result<T, WalletMetadataBackupFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw TestFailure('$failure'),
};
