class BullException implements Exception {
  final String message;

  BullException(this.message);

  @override
  String toString() => message;
}

class BullError implements Error {
  final String message;

  BullError(this.message);

  @override
  String toString() => message;

  @override
  StackTrace? get stackTrace => StackTrace.current;
}
