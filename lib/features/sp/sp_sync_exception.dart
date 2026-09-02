/// Thrown when an SP sync tick failed. The sync coordinator reports per-kind
/// failures by exception, so the `Err` the facade returns has to be raised.
final class SpSyncException implements Exception {
  final String? logMessage;

  const SpSyncException(this.logMessage);

  @override
  String toString() => 'SpSyncException($logMessage)';
}
