/// Advisory telemetry, kept inside the feature. Public UI contracts expose
/// categories only, never counters or identifiers.
final class AttemptObservation {
  final int attempts;
  final int requests;
  final int failures;
  final DateTime windowStartedAt;
  final DateTime? resetsAt;

  /// Public snapshots deliberately truncate timestamps to UTC hours.
  int get publicWindow {
    final utc = windowStartedAt.toUtc();
    return DateTime.utc(
      utc.year,
      utc.month,
      utc.day,
      utc.hour,
    ).millisecondsSinceEpoch;
  }

  AttemptObservation({
    required this.attempts,
    required this.requests,
    required this.failures,
    required this.windowStartedAt,
    this.resetsAt,
  }) {
    final reset = resetsAt;
    if (attempts < 0 ||
        requests < attempts ||
        failures < 0 ||
        failures > attempts ||
        (reset != null && !reset.isAfter(windowStartedAt))) {
      throw const FormatException('Invalid attempt telemetry');
    }
  }
}

final class AttemptSnapshot {
  final DateTime collectionStartedAt;
  final Map<String, AttemptObservation> entries;

  AttemptSnapshot({
    required this.collectionStartedAt,
    required Map<String, AttemptObservation> entries,
  }) : entries = Map.unmodifiable(entries);
}
