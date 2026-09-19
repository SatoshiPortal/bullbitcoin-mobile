import 'dart:async';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/data_backup_status.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/manage_data_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class DataBackupSettingsState {
  final DataBackupStatus? data;
  final bool loading;
  final bool working;
  final bool deleted;
  final BackupSettingsFailure? failure;
  final BackupSettingsFailure? readFailure;
  const DataBackupSettingsState({
    this.data,
    this.loading = false,
    this.working = false,
    this.deleted = false,
    this.failure,
    this.readFailure,
  });
}

class DataBackupSettingsCubit extends Cubit<DataBackupSettingsState> {
  final LoadDataBackupStatusUsecase _load;
  final WatchDataBackupStatusUsecase _watch;
  final SetDataBackupEnabledUsecase _setEnabled;
  final PublishDataBackupUsecase _publish;
  final DeleteDataBackupUsecase _delete;
  StreamSubscription<void>? _subscription;
  bool _refreshing = false, _refreshAgain = false;
  int _action = 0;

  DataBackupSettingsCubit(
    this._load,
    this._watch,
    this._setEnabled,
    this._publish,
    this._delete,
  ) : super(const DataBackupSettingsState(loading: true));

  Future<void> start() async {
    _subscription ??= _watch.execute().listen(
      (_) => unawaited(refresh()),
      onError: (Object _) {
        if (!isClosed) {
          emit(
            DataBackupSettingsState(
              data: state.data,
              working: state.working,
              failure: state.failure,
              readFailure: const BackupSettingsUnexpectedFailure(),
            ),
          );
        }
      },
    );
    await refresh();
  }

  Future<void> refresh() async {
    if (isClosed) return;
    _refreshAgain = true;
    if (_refreshing) return;
    _refreshing = true;
    try {
      do {
        _refreshAgain = false;
        final result = await _load.execute();
        if (isClosed) return;
        if (_refreshAgain) continue;
        emit(switch (result) {
          Ok(:final value) => DataBackupSettingsState(
            data: value,
            working: state.working,
            deleted: state.deleted,
            failure: state.failure,
          ),
          Err(:final failure) => DataBackupSettingsState(
            data: state.data,
            working: state.working,
            failure: state.failure,
            readFailure: failure,
          ),
        });
      } while (_refreshAgain);
    } finally {
      _refreshing = false;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    // Off must still reach the owner during a running upload or failed status read.
    if (enabled && state.working) return;
    await _run(() => _setEnabled.execute(enabled));
  }

  Future<void> publish({
    WalletBackupInspection? replace,
    bool confirmed = false,
  }) async {
    if (state.working) return;
    await _run(
      () async => (await _publish.execute(
        replace: replace,
        confirmed: confirmed,
      )).map((_) {}),
    );
  }

  Future<void> delete({required bool confirmed}) async {
    if (state.working || !confirmed) return;
    await _run(() => _delete.execute(confirmed: confirmed), deleting: true);
  }

  Future<void> _run(
    Future<Result<void, BackupSettingsFailure>> Function() action, {
    bool deleting = false,
  }) async {
    final request = ++_action;
    emit(DataBackupSettingsState(data: state.data, working: true));
    final result = await action();
    if (isClosed || request != _action) return;
    emit(switch (result) {
      Ok() => DataBackupSettingsState(data: state.data, deleted: deleting),
      Err(:final failure) => DataBackupSettingsState(
        data: state.data,
        failure: failure,
      ),
    });
    await refresh();
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
