import 'log_entry.dart';

final class LogFilter {
  final String query;
  final Set<LogSeverity> severities;
  final DateTime? startDate;
  final DateTime? endDate;
  final String _normalizedQuery;
  final DateTime? _inclusiveEndDate;

  LogFilter({
    this.query = '',
    this.severities = const {},
    this.startDate,
    this.endDate,
  }) : _normalizedQuery = query.trim().toLowerCase(),
       _inclusiveEndDate = endDate == null
           ? null
           : DateTime(
               endDate.year,
               endDate.month,
               endDate.day,
               23,
               59,
               59,
               999,
             );

  bool matches(LogEntry entry) {
    final inclusiveEndDate = _inclusiveEndDate;
    return (_normalizedQuery.isEmpty ||
            entry.displayText.toLowerCase().contains(_normalizedQuery)) &&
        (severities.isEmpty || severities.contains(entry.severity)) &&
        (startDate == null ||
            (entry.timestamp != null &&
                !entry.timestamp!.isBefore(startDate!))) &&
        (inclusiveEndDate == null ||
            (entry.timestamp != null &&
                !entry.timestamp!.isAfter(inclusiveEndDate)));
  }
}
