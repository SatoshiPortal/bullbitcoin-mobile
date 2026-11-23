class PayjoinEngineException implements Exception {
  final String message;

  const PayjoinEngineException(this.message);

  @override
  String toString() => message;
}

/// A sender start that failed after its session was persisted: the
/// directory post did not go through, the row keeps the signed original and
/// its poll and fallback watcher are armed. Distinct from every other start
/// failure so a caller can tell "my post failed, the session is mine" from a
/// rejection on behalf of another live session for the same payment.
class PayjoinSenderKeptException extends PayjoinEngineException {
  final String originalTxId;
  final Object cause;
  final bool publicationUnknown;

  PayjoinSenderKeptException(
    this.originalTxId,
    this.cause, {
    this.publicationUnknown = false,
  }) : super('Sender retained after directory publication failed');
}

/// Refuses a new operation after its captured runtime family is inactive.
final class PayjoinRuntimeInactiveException implements Exception {
  const PayjoinRuntimeInactiveException();
}
