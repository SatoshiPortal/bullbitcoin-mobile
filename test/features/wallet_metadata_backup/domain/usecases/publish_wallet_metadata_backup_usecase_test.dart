import 'dart:convert';

import 'package:bb_mobile/core/utils/clock.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/data/wallet_metadata_snapshot_codec.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/data/wallet_metadata_snapshot_composition_repository_impl.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_backup_state.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_encrypted_snapshot.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_key_material.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_publish_outcome.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_record.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_remote_head.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_snapshot.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/repositories/wallet_metadata_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/repositories/wallet_metadata_remote_repository.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_snapshot_cryptor.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/usecases/publish_wallet_metadata_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_failure.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_contributor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stores one blob and clears only the captured dirty revision', () async {
    final states = _StateRepository(
      WalletMetadataBackupState.initial.withEnabled(true),
    );
    final remote = _RemoteRepository()
      ..fetchResults.add(const WalletMetadataRemoteAbsent());
    remote.beforeStore = states.markDirty;
    final usecase = _usecase(states: states, remote: remote);

    final result = await usecase.execute(keyMaterial: _keyMaterial);

    expect(_ok(result).status, WalletMetadataPublishStatus.stored);
    expect(remote.storeCalls, 1);
    expect(remote.stored?.plaintext.records, hasLength(1));
    expect(states.state.dirty, isTrue);
    expect(states.state.dirtyRevision, 2);
    expect(states.state.verifiedHead?.remoteGeneration, 1);
  });

  test('refetches and recomposes once after a conflict', () async {
    final states = _StateRepository(
      WalletMetadataBackupState.initial.withEnabled(true),
    );
    final remote = _RemoteRepository()
      ..fetchResults.addAll(const [
        WalletMetadataRemoteAbsent(),
        WalletMetadataRemoteAbsent(),
      ])
      ..conflictsRemaining = 1;

    final result = await _usecase(
      states: states,
      remote: remote,
    ).execute(keyMaterial: _keyMaterial);

    expect(_ok(result).status, WalletMetadataPublishStatus.stored);
    expect(remote.fetchCalls, 2);
    expect(remote.storeCalls, 2);
  });

  test('returns the second CAS conflict and leaves the backup dirty', () async {
    final states = _StateRepository(
      WalletMetadataBackupState.initial.withEnabled(true),
    );
    final remote = _RemoteRepository()
      ..fetchResults.addAll(const [
        WalletMetadataRemoteAbsent(),
        WalletMetadataRemoteAbsent(),
      ])
      ..conflictsRemaining = 2;

    final result = await _usecase(
      states: states,
      remote: remote,
    ).execute(keyMaterial: _keyMaterial);

    expect(result, isA<Err>());
    expect((result as Err).failure, isA<WalletMetadataBackupConflictFailure>());
    expect(remote.fetchCalls, 2);
    expect(remote.storeCalls, 2);
    expect(states.state.dirty, isTrue);
  });

  test('verifies an unchanged remote snapshot without storing', () async {
    final states = _StateRepository(
      WalletMetadataBackupState.initial.withEnabled(true),
    );
    final remote = _RemoteRepository()
      ..fetchResults.add(WalletMetadataRemotePresent(_head([_ownedRecord])));

    final result = await _usecase(
      states: states,
      remote: remote,
    ).execute(keyMaterial: _keyMaterial);

    expect(_ok(result).status, WalletMetadataPublishStatus.unchanged);
    expect(remote.storeCalls, 0);
    expect(states.state.dirty, isFalse);
    expect(states.state.verifiedHead, isNotNull);
  });

  test('preserves unknown remote records in the replacement blob', () async {
    final states = _StateRepository(
      WalletMetadataBackupState.initial.withEnabled(true),
    );
    final unknown = WalletMetadataRecord(
      type: 'future.metadata',
      version: 7,
      scope: const {'wallet': 'future'},
      recordId: 'future-1',
      payload: const {'opaque': true},
    );
    final remote = _RemoteRepository()
      ..fetchResults.add(WalletMetadataRemotePresent(_head([unknown])));

    final result = await _usecase(
      states: states,
      remote: remote,
    ).execute(keyMaterial: _keyMaterial);
    expect(result, isA<Ok>());

    expect(
      remote.stored?.plaintext.records.map((record) => record.type),
      contains('future.metadata'),
    );
  });

  test('preserves an unknown version of a known record type', () async {
    final states = _StateRepository(
      WalletMetadataBackupState.initial.withEnabled(true),
    );
    final futureOwned = WalletMetadataRecord(
      type: 'owned',
      version: 2,
      scope: const {'wallet': 'future'},
      recordId: 'future-owned',
      payload: const {'opaque': true},
    );
    final remote = _RemoteRepository()
      ..fetchResults.add(WalletMetadataRemotePresent(_head([futureOwned])));

    final result = await _usecase(
      states: states,
      remote: remote,
    ).execute(keyMaterial: _keyMaterial);

    expect(result, isA<Ok>());
    expect(remote.stored?.plaintext.records, contains(futureOwned));
    expect(remote.stored?.plaintext.records, contains(_ownedRecord));
  });

  test('blocks publication after observing a newer envelope', () async {
    final states = _StateRepository(
      WalletMetadataBackupState.initial.withEnabled(true),
    );
    final remote = _RemoteRepository()
      ..fetchResults.add(
        WalletMetadataRemoteUnsupported(
          generation: 4,
          etag: 'c'.padLeft(64, 'c'),
          envelopeVersion: 2,
        ),
      );

    final result = await _usecase(
      states: states,
      remote: remote,
    ).execute(keyMaterial: _keyMaterial);

    expect(result, isA<Err>());
    expect(
      (result as Err).failure,
      isA<WalletMetadataBackupUpdateRequiredFailure>(),
    );
    expect(states.state.unsupportedNewerEnvelope?.envelopeVersion, 2);
    expect(remote.storeCalls, 0);
  });
}

PublishWalletMetadataBackupUsecase _usecase({
  required _StateRepository states,
  required _RemoteRepository remote,
}) {
  return PublishWalletMetadataBackupUsecase(
    stateRepository: states,
    remoteRepository: remote,
    compositionRepository:
        const WalletMetadataSnapshotCompositionRepositoryImpl(),
    snapshotCryptor: const _SnapshotCryptor(),
    contributors: [_Contributor()],
    clock: const _Clock(),
  );
}

final class _StateRepository implements WalletMetadataBackupStateRepository {
  WalletMetadataBackupState state;
  _StateRepository(this.state);

  void markDirty() => state = state.markDirty();

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

final class _RemoteRepository implements WalletMetadataRemoteRepository {
  final List<WalletMetadataRemoteFetchResult> fetchResults = [];
  int fetchCalls = 0;
  int storeCalls = 0;
  int conflictsRemaining = 0;
  void Function()? beforeStore;
  WalletMetadataEncryptedSnapshot? stored;

  @override
  Future<Result<WalletMetadataRemoteFetchResult, WalletMetadataBackupFailure>>
  fetch({required WalletMetadataKeyMaterial keyMaterial}) async {
    return Ok(fetchResults[fetchCalls++]);
  }

  @override
  Future<Result<WalletMetadataRemoteStoreReceipt, WalletMetadataBackupFailure>>
  store({
    required WalletMetadataKeyMaterial keyMaterial,
    required WalletMetadataEncryptedSnapshot snapshot,
    required int generation,
    required String? expectedEtag,
  }) async {
    storeCalls++;
    beforeStore?.call();
    beforeStore = null;
    if (conflictsRemaining > 0) {
      conflictsRemaining--;
      return const Err(WalletMetadataBackupConflictFailure());
    }
    stored = snapshot;
    return Ok(
      WalletMetadataRemoteStoreReceipt(
        generation: generation,
        etag: 'a'.padLeft(64, 'a'),
      ),
    );
  }

  @override
  Future<Result<void, WalletMetadataBackupFailure>> delete({
    required WalletMetadataKeyMaterial keyMaterial,
  }) async => const Ok(null);
}

final class _SnapshotCryptor implements WalletMetadataSnapshotCryptor {
  const _SnapshotCryptor();

  @override
  Result<WalletMetadataEncryptedSnapshot, WalletMetadataBackupFailure> build({
    required WalletMetadataKeyMaterial keyMaterial,
    required int revision,
    required int createdAt,
    required List<WalletMetadataRecord> records,
    required List<WalletMetadataSection> sections,
  }) {
    const codec = WalletMetadataSnapshotCodec();
    final snapshot = WalletMetadataSnapshot(
      parentFingerprint: keyMaterial.parentFingerprint,
      revision: revision,
      createdAt: createdAt,
      recordsHash: codec.recordsHash(records),
      recordCount: records.length,
      sections: sections,
      records: records,
    );
    return Ok(
      WalletMetadataEncryptedSnapshot(
        plaintext: snapshot,
        ciphertext: base64.encode(List.filled(64, 1)),
      ),
    );
  }

  @override
  Result<WalletMetadataSnapshot, WalletMetadataBackupFailure> decrypt({
    required WalletMetadataKeyMaterial keyMaterial,
    required String ciphertext,
  }) => throw UnimplementedError();
}

final class _Contributor implements WalletMetadataContributor {
  @override
  String get recordType => 'owned';
  @override
  Set<int> get supportedVersions => const {1};
  @override
  Future<Result<List<WalletMetadataRecord>, WalletMetadataBackupFailure>>
  exportRecords() async => Ok([_ownedRecord]);
  @override
  WalletMetadataRecordValidation validateRecord(WalletMetadataRecord record) =>
      WalletMetadataRecordValid(
        WalletMetadataImportIntent(contributorType: recordType, record: record),
      );
}

final _ownedRecord = WalletMetadataRecord(
  type: 'owned',
  version: 1,
  scope: const {'wallet': 'w1'},
  recordId: 'owned-1',
  payload: const {'label': 'local'},
);

final _keyMaterial = WalletMetadataKeyMaterial(
  xprvBase58: 'xprv',
  parentFingerprint: '627ef3a6',
);

WalletMetadataRemoteHead _head(List<WalletMetadataRecord> records) {
  const codec = WalletMetadataSnapshotCodec();
  final sections = records.map((record) => record.type).toSet().map((type) {
    final selected = records.where((record) => record.type == type).toList();
    return WalletMetadataSection(
      type: type,
      versions: selected.map((record) => record.version).toSet().toList(),
      recordCount: selected.length,
      recordsHash: codec.recordsHash(selected),
    );
  }).toList();
  final snapshot = WalletMetadataSnapshot(
    parentFingerprint: '627ef3a6',
    revision: 1,
    createdAt: 1,
    recordsHash: codec.recordsHash(records),
    recordCount: records.length,
    sections: sections,
    records: records,
  );
  return WalletMetadataRemoteHead(
    generation: 1,
    etag: 'b'.padLeft(64, 'b'),
    snapshot: snapshot,
    canonicalContentHash: codec.contentHash(
      records: records,
      sections: sections,
    ),
  );
}

final class _Clock implements Clock {
  const _Clock();
  @override
  DateTime nowUtc() => DateTime.fromMillisecondsSinceEpoch(10000, isUtc: true);
}

T _ok<T>(Result<T, WalletMetadataBackupFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw TestFailure('$failure'),
};
