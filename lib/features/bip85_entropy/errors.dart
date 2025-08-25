class Bip85EntropyError implements Exception {
  final String message;

  Bip85EntropyError(this.message);

  @override
  String toString() => message;
}
