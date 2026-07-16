import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_backup_state.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_encrypted_snapshot.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_key_material.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_remote_head.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/repositories/wallet_metadata_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/repositories/wallet_metadata_remote_repository.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/usecases/delete_wallet_metadata_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_failure.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_key_material_port.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('requires publication to be disabled before remote deletion', () async {
    final state = _StateRepository(
      WalletMetadataBackupState.initial.withEnabled(true),
    );
    final remote = _RemoteRepository();
    final keyMaterial = _KeyMaterialPort();

    final result = await DeleteWalletMetadataBackupUsecase(
      stateRepository: state,
      remoteRepository: remote,
      keyMaterialPort: keyMaterial,
    ).execute();

    expect(
      (result as Err).failure,
      isA<WalletMetadataBackupDeleteRequiresDisabledFailure>(),
    );
    expect(keyMaterial.calls, 0);
    expect(remote.deleteCalls, 0);
  });

  test(
    'deletes authoritatively and clears all remote checkpoint state',
    () async {
      final state = _StateRepository(
        WalletMetadataBackupState.initial.recordVerifiedHead(
          head: WalletMetadataBackupVerifiedHead(
            remoteGeneration: 3,
            remoteEtag: 'a'.padLeft(64, 'a'),
            snapshotRevision: 5,
            canonicalContentHash: 'b'.padLeft(64, 'b'),
            verifiedAt: 42,
          ),
          expectedDirtyRevision: 0,
        ),
      );
      final remote = _RemoteRepository();

      final result = await DeleteWalletMetadataBackupUsecase(
        stateRepository: state,
        remoteRepository: remote,
        keyMaterialPort: _KeyMaterialPort(),
      ).execute();

      expect(result, isA<Ok>());
      expect(remote.deleteCalls, 1);
      expect(state.state.verifiedHead, isNull);
      expect(state.state.lastSucceededAt, isNull);
    },
  );
}

final class _StateRepository implements WalletMetadataBackupStateRepository {
  WalletMetadataBackupState state;

  _StateRepository(this.state);

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
  int deleteCalls = 0;

  @override
  Future<Result<void, WalletMetadataBackupFailure>> delete({
    required WalletMetadataKeyMaterial keyMaterial,
  }) async {
    deleteCalls++;
    return const Ok(null);
  }

  @override
  Future<Result<WalletMetadataRemoteFetchResult, WalletMetadataBackupFailure>>
  fetch({required WalletMetadataKeyMaterial keyMaterial}) =>
      throw UnimplementedError();

  @override
  Future<Result<WalletMetadataRemoteStoreReceipt, WalletMetadataBackupFailure>>
  store({
    required WalletMetadataKeyMaterial keyMaterial,
    required WalletMetadataEncryptedSnapshot snapshot,
    required int generation,
    required String? expectedEtag,
  }) => throw UnimplementedError();
}

final class _KeyMaterialPort implements WalletMetadataKeyMaterialPort {
  int calls = 0;

  @override
  Future<Result<WalletMetadataKeyMaterial, WalletMetadataBackupFailure>>
  deriveLocal() async {
    calls++;
    return Ok(
      WalletMetadataKeyMaterial(
        xprvBase58: 'xprv',
        parentFingerprint: '627ef3a6',
      ),
    );
  }
}
