enum LogSeverity {
  finest,
  finer,
  fine,
  config,
  info,
  warning,
  severe,
  shout,
  unknown,
}

class LogEntry {
  final String rawLine;
  final DateTime? timestamp;
  final String rawLevel;
  final LogSeverity severity;
  final String displayText;

  const LogEntry({
    required this.rawLine,
    required this.timestamp,
    required this.rawLevel,
    required this.severity,
    required this.displayText,
  });
}
