class ConfidentialSepaNotActivatedException implements Exception {
  final String message;

  const ConfidentialSepaNotActivatedException([
    this.message = 'Confidential SEPA recipient is not activated',
  ]);

  @override
  String toString() => message;
}
