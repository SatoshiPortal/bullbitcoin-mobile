import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/log_entry.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/delete_logs_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/export_logs_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/load_logs_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/share_logs_usecase.dart';
import 'package:bb_mobile/features/settings/presentation/logs_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LogsCubit extends Cubit<LogsState> {
  final LoadLogsUsecase _loadLogs;
  final DeleteLogsUsecase _deleteLogs;
  final ShareLogsUsecase _shareLogs;
  final ExportLogsUsecase _exportLogs;

  LogsCubit(this._loadLogs, this._deleteLogs, this._shareLogs, this._exportLogs)
    : super(const LogsState());

  Future<void> load() async {
    if (state.status != LogsStatus.loading) return;
    switch (await _loadLogs.execute()) {
      case Ok(:final value):
        emit(state.copyWith(status: LogsStatus.ready, entries: value));
      case Err(:final failure):
        emit(state.copyWith(status: LogsStatus.failure, failure: failure));
    }
  }

  Future<Result<void, SettingsFailure>> delete() => _deleteLogs.execute();
  Future<Result<void, SettingsFailure>> share(List<LogEntry> entries) =>
      _shareLogs.execute(entries);
  Future<Result<bool, SettingsFailure>> export(List<LogEntry> entries) =>
      _exportLogs.execute(entries);
}
