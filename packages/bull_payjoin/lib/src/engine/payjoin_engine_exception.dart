class PayjoinEngineException implements Exception {
  final String message;

  const PayjoinEngineException(this.message);

  @override
  String toString() => message;
}

/// This attempt was persisted but its directory POST failed.
class PayjoinSenderKeptException extends PayjoinEngineException {
  final String originalTxId;

  const PayjoinSenderKeptException(this.originalTxId)
    : super('Sender retained after directory publication failed');
}
