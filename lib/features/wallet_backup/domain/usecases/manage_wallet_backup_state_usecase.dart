import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
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
  static const _deadline = Duration(seconds: 30);
  final NostrIdentityFacade _identity;
  final WalletBackupStateRepository _state;
  int _request = 0;
  SetWalletBackupEnabledUsecase({
    required this._identity,
    required this._state,
  });

  @useResult
  Future<Result<void, WalletBackupFailure>> execute(
    bool enabled, {
    bool onlyIfUndecided = false,
  }) {
    final request = onlyIfUndecided ? _request : ++_request;
    return _setEnabled(enabled, request, onlyIfUndecided).timeout(
      _deadline,
      onTimeout: () {
        // A credential resolved after the deadline is no longer consent to enable.
        if (request == _request) _request++;
        return const Err(WalletBackupTimeoutFailure());
      },
    );
  }

  Future<Result<void, WalletBackupFailure>> _setEnabled(
    bool enabled,
    int request,
    bool onlyIfUndecided,
  ) async {
    // Consent changes do not wait for publication, recovery or deletion.
    if (!enabled) {
      return _state.setEnabled(false, onlyIfUndecided: onlyIfUndecided);
    }
    if (request != _request) return const Ok(null);
    if (onlyIfUndecided) {
      switch (await _state.getControl()) {
        case Err(:final failure):
          return Err(failure);
        case Ok(value: final control) when control.enabled != null:
          return const Ok(null);
        case Ok():
          break;
      }
      if (request != _request) return const Ok(null);
    }
    final resolved = await _identity.resolve();
    if (request != _request) return const Ok(null);
    return switch (resolved) {
      Err() => const Err(WalletBackupCredentialFailure()),
      Ok() => await _state.setEnabled(true, onlyIfUndecided: onlyIfUndecided),
    };
  }
}
