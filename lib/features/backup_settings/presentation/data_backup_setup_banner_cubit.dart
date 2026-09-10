import 'dart:async';

import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/features/wizard/public/wizard_facade.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

/// What the home page says about Data Backup while it is being set up.
sealed class DataBackupSetupBannerState {
  const DataBackupSetupBannerState();
}

/// Nothing to show.
final class DataBackupSetupHidden extends DataBackupSetupBannerState {
  const DataBackupSetupHidden();
}

/// The wizard's Data Backup opt-in is being applied: the server is being
/// asked for an existing backup.
final class DataBackupSettingUp extends DataBackupSetupBannerState {
  const DataBackupSettingUp();
}

/// A backup was found and is being written into the wallet.
final class DataBackupRestoring extends DataBackupSetupBannerState {
  const DataBackupRestoring();
}

/// The opt-in could not be applied; the choice is kept for a retry.
final class DataBackupSetupFailed extends DataBackupSetupBannerState {
  const DataBackupSetupFailed();
}

/// Applies the wizard's pending choices once the user is on the home page,
/// so onboarding never waits for the server, and reports progress there.
class DataBackupSetupBannerCubit extends Cubit<DataBackupSetupBannerState> {
  final Future<bool> Function() _hasPendingChoices;
  final Future<Result<void, WizardFailure>> Function({
    Set<String> defaultCreatedWalletIds,
  })
  _applyPendingChoices;
  final Stream<Result<WalletBackupState, WalletBackupFailure>> Function()
  _watchState;
  StreamSubscription<Result<WalletBackupState, WalletBackupFailure>>?
  _subscription;
  bool _applyingChoices = false;
  bool _restoring = false;
  bool _closing = false;

  DataBackupSetupBannerCubit({
    required Future<bool> Function() hasPendingChoices,
    required Future<Result<void, WizardFailure>> Function({
      Set<String> defaultCreatedWalletIds,
    })
    applyPendingChoices,
    required Stream<Result<WalletBackupState, WalletBackupFailure>> Function()
    watchState,
  }) : this._(hasPendingChoices, applyPendingChoices, watchState);

  DataBackupSetupBannerCubit._(
    this._hasPendingChoices,
    this._applyPendingChoices,
    this._watchState,
  ) : super(const DataBackupSetupHidden());

  Future<void> start({Set<String> defaultCreatedWalletIds = const {}}) async {
    if (isClosed || _closing) return;
    _subscription ??= _watchState().listen((result) {
      if (isClosed || _closing) return;
      if (result case Ok(:final value)) {
        _restoring = value.recoveryState == WalletBackupRecoveryState.applying;
        _render();
      }
    });
    await applyPendingChoices(defaultCreatedWalletIds: defaultCreatedWalletIds);
  }

  /// Runs the pending wizard choices, or retries them after a failure.
  Future<void> applyPendingChoices({
    Set<String> defaultCreatedWalletIds = const {},
  }) async {
    if (_applyingChoices || isClosed || _closing) return;
    _applyingChoices = true;
    try {
      final pending = await _hasPendingChoices();
      if (isClosed || _closing) return;
      if (!pending) {
        emit(const DataBackupSetupHidden());
        return;
      }
      _render();
      final result = await _applyPendingChoices(
        defaultCreatedWalletIds: defaultCreatedWalletIds,
      );
      _applyingChoices = false;
      if (isClosed || _closing) return;
      switch (result) {
        case Ok():
          emit(const DataBackupSetupHidden());
          _render();
        case Err():
          emit(const DataBackupSetupFailed());
      }
    } on Exception {
      if (!isClosed && !_closing) emit(const DataBackupSetupFailed());
    } finally {
      _applyingChoices = false;
    }
  }

  void _render() {
    if (_restoring) return emit(const DataBackupRestoring());
    if (_applyingChoices) return emit(const DataBackupSettingUp());
    if (state is DataBackupSetupFailed) return;
    emit(const DataBackupSetupHidden());
  }

  @override
  Future<void> close() async {
    _closing = true;
    await _subscription?.cancel();
    return super.close();
  }
}
