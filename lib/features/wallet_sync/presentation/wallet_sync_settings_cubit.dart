import 'package:bb_mobile/core/wallet/domain/entities/wallet_sync_settings.dart';
import 'package:bb_mobile/features/wallet_sync/domain/usecases/load_wallet_sync_settings_usecase.dart';
import 'package:bb_mobile/features/wallet_sync/domain/usecases/save_wallet_sync_settings_usecase.dart';
import 'package:bb_mobile/features/wallet_sync/domain/wallet_sync_options_failure.dart';
import 'package:bb_mobile/features/wallet_sync/domain/wallet_sync_selection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

sealed class WalletSyncSettingsState {
  const WalletSyncSettingsState();
}

final class WalletSyncSettingsLoading extends WalletSyncSettingsState {
  const WalletSyncSettingsLoading();
}

final class WalletSyncSettingsUnavailable extends WalletSyncSettingsState {
  final WalletSyncOptionsFailure failure;
  const WalletSyncSettingsUnavailable(this.failure);
}

final class WalletSyncSettingsReady extends WalletSyncSettingsState {
  final WalletSyncSettings settings;
  final bool saving;
  final WalletSyncOptionsFailure? failure;
  const WalletSyncSettingsReady(
    this.settings, {
    this.saving = false,
    this.failure,
  });
}

class WalletSyncSettingsCubit extends Cubit<WalletSyncSettingsState> {
  final String walletId;
  final LoadWalletSyncSettingsUsecase _load;
  final SaveWalletSyncSettingsUsecase _save;

  WalletSyncSettingsCubit({
    required this.walletId,
    required this._load,
    required this._save,
  }) : super(const WalletSyncSettingsLoading());

  Future<void> load() async {
    final result = await _load.execute(walletId);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(WalletSyncSettingsReady(value));
      case Err(:final failure):
        emit(WalletSyncSettingsUnavailable(failure));
    }
  }

  Future<void> save(
    WalletSyncSelection selection, {
    bool earlierOnly = false,
  }) async {
    final current = state;
    if (current is! WalletSyncSettingsReady || current.saving) return;
    emit(WalletSyncSettingsReady(current.settings, saving: true));
    final result = await _save.execute(
      walletId: walletId,
      selection: selection,
      earlierOnly: earlierOnly,
    );
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(WalletSyncSettingsReady(value));
      case Err(:final failure):
        emit(WalletSyncSettingsUnavailable(failure));
    }
  }
}
