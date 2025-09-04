class RecoverBullVaultRecoveryError implements Exception {
  final String message;
  RecoverBullVaultRecoveryError(this.message);

  @override
  String toString() => message;
}
