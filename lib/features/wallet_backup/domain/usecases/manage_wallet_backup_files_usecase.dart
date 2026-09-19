import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_file.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_codec_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_file_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_snapshot_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_operation_queue.dart';
import 'package:meta/meta.dart';

final class PickWalletBackupFileUsecase {
  final WalletBackupFileRepository _files;
  const PickWalletBackupFileUsecase(this._files);
  @useResult
  Future<Result<String?, WalletBackupFailure>> execute() => _files.pick();
}

final class ExportWalletBackupFileUsecase {
  final WalletBackupOperationQueue _operations;
  final NostrIdentityFacade _identity;
  final WalletBackupStateRepository _state;
  final WalletBackupSnapshotRepository _snapshots;
  final WalletBackupCodecRepository _codec;
  final WalletBackupFileRepository _files;
  const ExportWalletBackupFileUsecase({
    required this._operations,
    required this._identity,
    required this._state,
    required this._snapshots,
    required this._codec,
    required this._files,
  });

  @useResult
  Future<Result<bool, WalletBackupFailure>> execute(
    WalletBackupFileFormat format, {
    bool confirmed = false,
  }) async {
    if (format == WalletBackupFileFormat.readable && !confirmed) {
      return const Err(WalletBackupConfirmationRequiredFailure());
    }
    // Only capture/encoding shares the mutation queue. Native save interaction
    // need not block publication, nor retain the credential used by _encode.
    final encoded = await _operations.run(() => _encode(format));
    return switch (encoded) {
      Err(:final failure) => Err(failure),
      Ok(:final value) => await _files.save(value, format: format),
    };
  }

  Future<Result<String, WalletBackupFailure>> _encode(
    WalletBackupFileFormat format,
  ) async {
    switch (await _state.getControl()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final control) when control.recoveryIncomplete:
        return const Err(WalletBackupIncompleteFailure());
      case Ok():
        break;
    }
    final resolved = await _identity.resolve();
    if (resolved case Err()) return const Err(WalletBackupCredentialFailure());
    final credential =
        (resolved as Ok<BackupCredential, NostrIdentityFailure>).value;
    var changed = false, observationFailed = false;
    final subscription = _snapshots.changes.listen(
      (_) => changed = true,
      onError: (Object _) => observationFailed = true,
    );
    try {
      final captured = await _snapshots.capture(credential);
      if (captured case Err(:final failure)) return Err(failure);
      if (observationFailed) return const Err(WalletBackupStorageFailure());
      if (changed) return const Err(WalletBackupChangedFailure());
      return _codec.encodeFile(
        (captured as Ok<WalletBackupSnapshot, WalletBackupFailure>).value,
        credential,
        format: format,
      );
    } finally {
      await subscription.cancel();
    }
  }
}

final class DecodeWalletBackupFileUsecase {
  final NostrIdentityFacade _identity;
  final WalletBackupCodecRepository _codec;
  const DecodeWalletBackupFileUsecase({
    required this._identity,
    required this._codec,
  });
  @useResult
  Future<Result<WalletBackupFile, WalletBackupFailure>> execute(
    String source, {
    String? words,
  }) async {
    if (source.length > WalletBackupFile.maximumBytes) {
      return const Err(WalletBackupTooLargeFailure());
    }
    BackupCredential? credential;
    if (words != null) {
      switch (_identity.fromWords(words)) {
        case Err():
          return const Err(WalletBackupCredentialFailure());
        case Ok(:final value):
          credential = value;
      }
    } else {
      switch (await _identity.resolve()) {
        case Err():
          break; // A public readable file can be inspected seedless.
        case Ok(:final value):
          credential = value;
      }
    }
    return _codec.decodeFile(source, credential: credential);
  }
}
