import 'package:primitives/primitives.dart';
import 'package:bull_logs/src/domain/log_entry.dart';
import 'package:bull_logs/src/domain/logs_failure.dart';
import 'package:bull_logs/src/domain/usecases/delete_logs_usecase.dart';
import 'package:bull_logs/src/domain/usecases/export_logs_usecase.dart';
import 'package:bull_logs/src/domain/usecases/filter_logs_usecase.dart';
import 'package:bull_logs/src/domain/usecases/load_logs_usecase.dart';
import 'package:bull_logs/src/domain/usecases/share_logs_usecase.dart';
import 'package:bull_logs/src/presentation/logs_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LogsCubit extends Cubit<LogsState> {
  final LoadLogsUsecase _loadLogs;
  final DeleteLogsUsecase _deleteLogs;
  final ShareLogsUsecase _shareLogs;
  final ExportLogsUsecase _exportLogs;
  final FilterLogsUsecase _filterLogs;

  LogsCubit(
    this._loadLogs,
    this._deleteLogs,
    this._shareLogs,
    this._exportLogs,
    this._filterLogs,
  ) : super(const LogsState());

  Future<void> load() async {
    if (state.status != LogsStatus.loading) return;
    switch (await _loadLogs.execute()) {
      case Ok(:final value):
        _emitReady(value);
      case Err(:final failure):
        emit(
          LogsState(
            status: LogsStatus.failure,
            entries: state.entries,
            visibleEntries: state.visibleEntries,
            failure: failure,
            query: state.query,
            severities: state.severities,
            startDate: state.startDate,
            endDate: state.endDate,
          ),
        );
    }
  }

  Future<Result<List<LogEntry>, LogsFailure>> refresh() async {
    final result = await _loadLogs.execute();
    if (result case Ok(:final value)) _emitReady(value);
    return result;
  }

  Future<Result<void, LogsFailure>> delete() async {
    final result = await _deleteLogs.execute();
    if (result case Ok()) {
      emit(
        LogsState(
          status: state.status,
          failure: state.failure,
          query: state.query,
          severities: state.severities,
          startDate: state.startDate,
          endDate: state.endDate,
        ),
      );
    }
    return result;
  }

  Future<Result<void, LogsFailure>> share(List<LogEntry> entries) =>
      _shareLogs.execute(entries);
  Future<Result<bool, LogsFailure>> export(List<LogEntry> entries) =>
      _exportLogs.execute(entries);

  void setQuery(String query) => _applyFilters(
    query: query,
    severities: state.severities,
    startDate: state.startDate,
    endDate: state.endDate,
  );

  void toggleSeverity(LogSeverity severity) {
    final next = {...state.severities};
    next.contains(severity) ? next.remove(severity) : next.add(severity);
    _applyFilters(severities: next);
  }

  void clearFilters() => _applyFilters(
    query: '',
    severities: const {},
    startDate: null,
    endDate: null,
    replaceDates: true,
  );

  void setDateRange(DateTime? startDate, DateTime? endDate) => _applyFilters(
    query: state.query,
    severities: state.severities,
    startDate: startDate,
    endDate: endDate,
    replaceDates: true,
  );

  void _applyFilters({
    String? query,
    Set<LogSeverity>? severities,
    DateTime? startDate,
    DateTime? endDate,
    bool replaceDates = false,
  }) {
    final nextQuery = query ?? state.query;
    final nextSeverities = severities ?? state.severities;
    final nextStartDate = replaceDates
        ? startDate
        : startDate ?? state.startDate;
    final nextEndDate = replaceDates ? endDate : endDate ?? state.endDate;
    final nextVisible = _filterLogs.execute(
      state.entries,
      query: nextQuery,
      severities: nextSeverities,
      startDate: nextStartDate,
      endDate: nextEndDate,
    );
    emit(
      LogsState(
        status: state.status,
        entries: state.entries,
        visibleEntries: nextVisible,
        failure: state.failure,
        query: nextQuery,
        severities: nextSeverities,
        startDate: nextStartDate,
        endDate: nextEndDate,
      ),
    );
  }

  void _emitReady(List<LogEntry> entries) {
    emit(
      LogsState(
        status: LogsStatus.ready,
        entries: entries,
        visibleEntries: _filterLogs.execute(
          entries,
          query: state.query,
          severities: state.severities,
          startDate: state.startDate,
          endDate: state.endDate,
        ),
        query: state.query,
        severities: state.severities,
        startDate: state.startDate,
        endDate: state.endDate,
      ),
    );
  }
}
