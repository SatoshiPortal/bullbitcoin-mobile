import 'package:bull_logs/src/domain/log_entry.dart';
import '../log_filter.dart';

class FilterLogsUsecase {
  const FilterLogsUsecase();

  List<LogEntry> execute(
    List<LogEntry> entries, {
    String query = '',
    Set<LogSeverity> severities = const {},
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final filter = LogFilter(
      query: query,
      severities: severities,
      startDate: startDate,
      endDate: endDate,
    );
    return entries.where(filter.matches).toList();
  }
}
