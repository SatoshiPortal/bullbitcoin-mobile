import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_encryption.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_remote_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';

final class BullnymWalletBackupRemoteRepository
    implements WalletBackupRemoteRepository {
  final BullnymFacade _bullnym;

  const BullnymWalletBackupRemoteRepository(this._bullnym);

  @override
  @useResult
  Future<Result<WalletBackupRemoteHead, WalletBackupFailure>> fetch() async =>
      switch (await _bullnym.fetchBackup(BullnymBackupStream.walletBackup)) {
        Err(:final failure) => Err(_mapFailure(failure)),
        Ok(:final value) => _head(value),
      };

  @override
  @useResult
  Future<Result<WalletBackupRemoteCheckpoint, WalletBackupFailure>> store({
    required WalletBackupRemoteHead current,
    required WalletBackupCiphertext ciphertext,
  }) async {
    try {
      return switch (await _bullnym.storeBackup(
        stream: BullnymBackupStream.walletBackup,
        currentHead: _bullnymHead(current),
        ciphertext: BullnymBackupCiphertext(ciphertext.value),
      )) {
        Err(:final failure) => Err(_mapFailure(failure)),
        Ok(:final value) => Ok(
          WalletBackupRemoteCheckpoint(
            generation: value.generation,
            etag: value.etag,
          ),
        ),
      };
    } on ArgumentError catch (error, trace) {
      log.warning(
        'Invalid wallet backup transport value',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(WalletBackupInvalidRemoteFailure());
    }
  }

  @override
  @useResult
  Future<Result<WalletBackupRemoteCheckpoint?, WalletBackupFailure>> delete({
    required WalletBackupRemoteHead current,
  }) async => switch (await _bullnym.deleteBackup(
    stream: BullnymBackupStream.walletBackup,
    currentHead: _bullnymHead(current),
  )) {
    Err(:final failure) => Err(_mapFailure(failure)),
    Ok(value: null) => const Ok(null),
    Ok(value: final value?) => Ok(
      WalletBackupRemoteCheckpoint(
        generation: value.generation,
        etag: value.etag,
      ),
    ),
  };

  Result<WalletBackupRemoteHead, WalletBackupFailure> _head(
    BullnymBackupHead head,
  ) {
    try {
      return Ok(
        head.found
            ? WalletBackupRemoteHead.present(
                generation: head.generation,
                etag: head.etag!,
                ciphertext: WalletBackupCiphertext(head.ciphertext!.value),
                ciphertextSha256: head.ciphertextSha256!,
                updatedAtSecs: head.updatedAtSecs!,
              )
            : WalletBackupRemoteHead.absent(
                generation: head.generation,
                etag: head.etag,
              ),
      );
    } on ArgumentError catch (error, trace) {
      log.warning(
        'Invalid wallet backup response',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(WalletBackupInvalidRemoteFailure());
    }
  }

  BullnymBackupHead _bullnymHead(WalletBackupRemoteHead head) => head.found
      ? BullnymBackupHead.present(
          generation: head.generation,
          etag: head.etag!,
          ciphertext: BullnymBackupCiphertext(head.ciphertext!.value),
          ciphertextSha256: head.ciphertextSha256!,
          updatedAtSecs: head.updatedAtSecs!,
        )
      : BullnymBackupHead.absent(generation: head.generation, etag: head.etag);
}

WalletBackupFailure _mapFailure(BullnymFailure failure) => switch (failure) {
  BullnymServerFailure(code: 'BackupHeadConflict') =>
    const WalletBackupHeadConflictFailure(),
  BullnymServerFailure(code: 'BackupBlobTooLarge') =>
    const WalletBackupTooLargeFailure(),
  BullnymAuthenticationFailure() => const WalletBackupSigningFailure(),
  BullnymNetworkFailure() => const WalletBackupRemoteUnavailableFailure(),
  BullnymInvalidResponseFailure() => const WalletBackupInvalidRemoteFailure(),
  BullnymInvalidInputFailure() ||
  BullnymServerFailure() => const WalletBackupRemoteRejectedFailure(),
  BullnymUnexpectedFailure() => const WalletBackupUnexpectedFailure(),
};
