/// The device-wide attempt-monitoring state shared by every monitored backup.
final class AttemptMonitoringState {
  final bool attemptMonitoringEnabled;
  final String? etag;
  final DateTime? lastSuccessfulCheckAt;
  final DateTime? collectionStartedAt;
  final int consecutiveFailures;
  final DateTime? lastUnavailabilityWarningAt;
  final DateTime? attemptsUnsupportedUntil;
  final int generation;
  final int revision;

  AttemptMonitoringState({
    required this.attemptMonitoringEnabled,
    required this.etag,
    required this.lastSuccessfulCheckAt,
    required this.collectionStartedAt,
    required this.consecutiveFailures,
    required this.lastUnavailabilityWarningAt,
    this.attemptsUnsupportedUntil,
    required this.generation,
    required this.revision,
  }) {
    if (consecutiveFailures < 0) {
      throw ArgumentError.value(consecutiveFailures, 'consecutiveFailures');
    }
    if (generation < 0) throw ArgumentError.value(generation, 'generation');
    if (revision < 0) throw ArgumentError.value(revision, 'revision');
  }

  /// Whether the key server is known, as of [now], to lack `/attempts`.
  bool attemptsUnsupportedAt(DateTime now) {
    final until = attemptsUnsupportedUntil;
    return until != null && now.isBefore(until);
  }

  /// Whether the key server started a new attempt collection since the last
  /// accepted snapshot, compared at one-second precision.
  bool isOtherCollection(DateTime startedAt) {
    final known = collectionStartedAt;
    return known != null && _second(known) != _second(startedAt);
  }

  static int _second(DateTime value) =>
      value.toUtc().millisecondsSinceEpoch ~/ 1000;
}
