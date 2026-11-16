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

  PayjoinSenderKeptException(this.originalTxId, this.cause)
    : super('Sender retained after directory publication failed');
}
