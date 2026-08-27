import 'package:bb_mobile/features/settings/domain/log_entry.dart';

class FilterLogsUsecase {
  const FilterLogsUsecase();

  List<LogEntry> execute(
    List<LogEntry> entries, {
    String query = '',
    Set<LogSeverity> severities = const {},
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final endOfDay = endDate == null
        ? null
        : DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);
    return entries.where((entry) {
      if (normalizedQuery.isNotEmpty &&
          !entry.displayText.toLowerCase().contains(normalizedQuery)) {
        return false;
      }
      if (severities.isNotEmpty && !severities.contains(entry.severity)) {
        return false;
      }
      if (startDate != null &&
          (entry.timestamp == null || entry.timestamp!.isBefore(startDate))) {
        return false;
      }
      if (endOfDay != null &&
          (entry.timestamp == null || entry.timestamp!.isAfter(endOfDay))) {
        return false;
      }
      return true;
    }).toList();
  }
}
