import 'package:bb_mobile/features/settings/domain/log_entry.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';

enum LogsStatus { loading, ready, failure }

class LogsState {
  final LogsStatus status;
  final List<LogEntry> entries;
  final SettingsFailure? failure;

  const LogsState({
    this.status = LogsStatus.loading,
    this.entries = const [],
    this.failure,
  });

  LogsState copyWith({
    LogsStatus? status,
    List<LogEntry>? entries,
    SettingsFailure? failure,
  }) => LogsState(
    status: status ?? this.status,
    entries: entries ?? this.entries,
    failure: failure ?? this.failure,
  );
}
