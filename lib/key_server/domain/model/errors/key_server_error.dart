class KeyServerError implements Exception {
  final String message;
  const KeyServerError(this.message);

  @override
  String toString() => 'KeyServerError: $message';
}

class BackupFileInvalidError extends KeyServerError {
  const BackupFileInvalidError() : super('Invalid backup file format');
}

class PasswordTooCommonError extends KeyServerError {
  const PasswordTooCommonError() : super('Password is too common');
}

class BackupKeyMismatchError extends KeyServerError {
  const BackupKeyMismatchError()
      : super('Backup key is not derived from default wallet');
}

class Bip85PathMissingError extends KeyServerError {
  const Bip85PathMissingError()
      : super('BIP85 path is missing from backup file');
}
