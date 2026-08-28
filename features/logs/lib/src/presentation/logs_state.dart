import 'package:bull_logs/src/domain/log_entry.dart';
import 'package:bull_logs/src/domain/logs_failure.dart';

enum LogsStatus { loading, ready, failure }

class LogsState {
  final LogsStatus status;
  final List<LogEntry> entries;
  final List<LogEntry> visibleEntries;
  final LogsFailure? failure;
  final String query;
  final Set<LogSeverity> severities;
  final DateTime? startDate;
  final DateTime? endDate;

  const LogsState({
    this.status = LogsStatus.loading,
    this.entries = const [],
    this.visibleEntries = const [],
    this.failure,
    this.query = '',
    this.severities = const {},
    this.startDate,
    this.endDate,
  });
}
