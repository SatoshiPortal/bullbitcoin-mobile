import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_diagnostics.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_file.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_codec_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_file_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';

final class PickWalletBackupFileUsecase {
  final WalletBackupFileRepository _files;
  const PickWalletBackupFileUsecase(this._files);
  @useResult
  Future<Result<String?, WalletBackupFailure>> execute() => _files.pick();
}

final class ExportWalletBackupFileUsecase {
  final NostrIdentityFacade _identity;
  final WalletBackupStateRepository _state;
  final WalletBackupCodecRepository _codec;
  final WalletBackupFileRepository _files;
  const ExportWalletBackupFileUsecase({
    required this._identity,
    required this._state,
    required this._codec,
    required this._files,
  });

  @useResult
  Future<Result<bool, WalletBackupFailure>> execute(
    WalletBackupFileFormat format, {
    bool confirmed = false,
  }) async {
    if (format == WalletBackupFileFormat.readable && !confirmed) {
      return logWalletBackupCompletion(
        WalletBackupOperation.export,
        const Err(WalletBackupConfirmationRequiredFailure()),
      );
    }
    // Preparing a file is read-only and does not wait for network mutations. The native save dialog has no user-interaction deadline.
    final encoded = await _encode(format).timeout(
      const Duration(minutes: 1),
      onTimeout: () => const Err(WalletBackupTimeoutFailure()),
    );
    final Result<bool, WalletBackupFailure> result = switch (encoded) {
      Err(:final failure) => Err(failure),
      Ok(:final value) => await _files.save(value, format: format),
    };
    return logWalletBackupCompletion(WalletBackupOperation.export, result);
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
    final beforeCapture = _codec.revision;
    final captured = await _codec.capture(credential);
    if (captured case Err(:final failure)) return Err(failure);
    // Recovery may have started since the first control read.
    switch (await _state.getControl()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final control) when control.recoveryIncomplete:
        return const Err(WalletBackupIncompleteFailure());
      case Ok():
        break;
    }
    if (_codec.revision < 0) return const Err(WalletBackupStorageFailure());
    if (_codec.revision != beforeCapture) {
      return const Err(WalletBackupChangedFailure());
    }
    return _codec.encodeFile(
      (captured as Ok<WalletBackupSnapshot, WalletBackupFailure>).value,
      credential,
      format: format,
    );
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
