import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_operation_queue.dart';
import 'package:meta/meta.dart';

final class GetWalletBackupControlUsecase {
  final WalletBackupStateRepository _state;
  const GetWalletBackupControlUsecase(this._state);
  @useResult
  Future<Result<WalletBackupControl, WalletBackupFailure>> execute() =>
      _state.getControl();
}

final class WatchWalletBackupStateUsecase {
  final WalletBackupStateRepository _state;
  const WatchWalletBackupStateUsecase(this._state);
  Stream<void> execute() => _state.changes;
}

final class GetWalletBackupStateUsecase {
  final NostrIdentityFacade _identity;
  final WalletBackupStateRepository _state;
  const GetWalletBackupStateUsecase(this._identity, this._state);
  @useResult
  Future<Result<WalletBackupState, WalletBackupFailure>> execute() async =>
      switch (await _identity.resolve()) {
        Err() => const Err(WalletBackupCredentialFailure()),
        Ok(:final value) => await _state.get(value.serverPublicKey),
      };
}

final class SetWalletBackupEnabledUsecase {
  final WalletBackupOperationQueue _operations;
  final NostrIdentityFacade _identity;
  final WalletBackupStateRepository _state;
  const SetWalletBackupEnabledUsecase({
    required this._operations,
    required this._identity,
    required this._state,
  });

  @useResult
  Future<Result<void, WalletBackupFailure>> execute(bool enabled) {
    // Off interrupts automatic work immediately. Enabling is ordered after any
    // active deletion/recovery, so an old queued job cannot undo deletion.
    if (!enabled) return _state.setEnabled(false);
    return _operations.run(
      () async => switch (await _identity.resolve()) {
        Err() => const Err(WalletBackupCredentialFailure()),
        Ok() => await _state.setEnabled(true),
      },
    );
  }
}
