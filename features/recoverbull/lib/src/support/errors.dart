class RecoverBullDataException implements Exception {
  final String message;

  const RecoverBullDataException(this.message);

  @override
  String toString() => message;
}
