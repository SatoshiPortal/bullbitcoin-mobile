class PayjoinEngineException implements Exception {
  final String message;

  const PayjoinEngineException(this.message);

  @override
  String toString() => message;
}
