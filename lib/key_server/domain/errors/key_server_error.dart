import 'package:recoverbull/recoverbull.dart' show KeyServerException;

class KeyServerError implements Exception {
  final String message;
  final KeyServerErrorType type;

  const KeyServerError._({
    required this.message,
    required this.type,
  });

  factory KeyServerError.fromException(KeyServerException e) {
    if (e.code == 401) {
      return const KeyServerError._(
        message:
            'Wrong password for this backup file. Please check your password.',
        type: KeyServerErrorType.invalidCredentials,
      );
    } else if (e.code == 429) {
      final cooldownEnd =
          e.requestedAt?.add(Duration(minutes: e.cooldownInMinutes!));
      final retryInMinutes = cooldownEnd?.difference(DateTime.now()).inMinutes;
      return KeyServerError._(
        message: retryInMinutes != null
            ? 'Rate-limited. Retry in $retryInMinutes minutes'
            : 'Rate-limited. Try again later',
        type: KeyServerErrorType.rateLimited,
      );
    } else if (e.code != null && e.code! >= 400 && e.code! < 500) {
      return const KeyServerError._(
        message: 'Rejected by the Key Server',
        type: KeyServerErrorType.rejected,
      );
    }
    return const KeyServerError._(
      message: 'Service unavailable. Please check your connection.',
      type: KeyServerErrorType.unavailable,
    );
  }

  const KeyServerError.failedToConnect()
      : this._(
          message:
              'Failed to connect to the target key server. Please try again later!',
          type: KeyServerErrorType.unavailable,
        );
  const KeyServerError.invalidBackupFile()
      : this._(
          message: 'Invalid backup file format',
          type: KeyServerErrorType.invalidBackupFile,
        );

  const KeyServerError.commonPassword()
      : this._(
          message: 'Password is too common',
          type: KeyServerErrorType.commonPassword,
        );

  const KeyServerError.keyMismatch()
      : this._(
          message: 'Backup key is not derived from default wallet',
          type: KeyServerErrorType.keyMismatch,
        );

  const KeyServerError.missingPath()
      : this._(
          message: 'BIP85 path is missing from backup file',
          type: KeyServerErrorType.missingPath,
        );
}

enum KeyServerErrorType {
  invalidCredentials,
  rateLimited,
  rejected,
  unavailable,
  invalidBackupFile,
  commonPassword,
  keyMismatch,
  missingPath,
}
