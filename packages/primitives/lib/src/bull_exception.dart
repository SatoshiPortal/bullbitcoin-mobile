class BullException implements Exception {
  final String message;

  BullException(this.message);

  @override
  String toString() => message;
}
