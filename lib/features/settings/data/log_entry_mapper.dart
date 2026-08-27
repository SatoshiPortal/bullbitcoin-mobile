import 'package:bb_mobile/features/settings/data/models/log_entry_model.dart';
import 'package:bb_mobile/features/settings/domain/log_entry.dart';

extension LogEntryModelMapper on LogEntryModel {
  LogEntry toDomain() {
    final displayParts = List<String>.of(columns);
    if (displayParts.isNotEmpty && displayParts.first.length > 7) {
      displayParts[0] = displayParts.first.substring(
        0,
        displayParts.first.length - 7,
      );
    }
    return LogEntry(
      rawLine: rawLine,
      timestamp: timestampText == null
          ? null
          : DateTime.tryParse(timestampText!),
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
