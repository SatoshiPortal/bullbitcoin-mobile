import 'package:bull_logs/src/data/log_entry_model.dart';
import 'package:bull_logs/src/domain/log_entry.dart';

extension LogEntryModelMapper on LogEntryModel {
  LogEntry toDomain() {
    final displayParts = List<String>.of(columns);
    final timestamp = timestampText == null
        ? null
        : DateTime.tryParse(timestampText!);
    if (displayParts.isNotEmpty && timestamp != null) {
      displayParts[0] = _formatTimestamp(timestamp);
    }
    return LogEntry(
      rawLine: rawLine,
      timestamp: timestamp,
      rawLevel: rawLevel,
      severity: switch (rawLevel) {
        'FINEST' => LogSeverity.finest,
        'FINER' => LogSeverity.finer,
        'FINE' => LogSeverity.fine,
        'CONFIG' => LogSeverity.config,
        'INFO' => LogSeverity.info,
        'WARNING' => LogSeverity.warning,
        'SEVERE' => LogSeverity.severe,
        'SHOUT' => LogSeverity.shout,
        _ => LogSeverity.unknown,
      },
      displayText: displayParts.join(' | '),
    );
  }
}

String _formatTimestamp(DateTime timestamp) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  final date =
      '${timestamp.year.toString().padLeft(4, '0')}-'
      '${twoDigits(timestamp.month)}-${twoDigits(timestamp.day)}T'
      '${twoDigits(timestamp.hour)}:${twoDigits(timestamp.minute)}:'
      '${twoDigits(timestamp.second)}';
  return timestamp.isUtc ? '${date}Z' : date;
}
