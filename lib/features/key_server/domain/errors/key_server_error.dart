import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:recoverbull/recoverbull.dart' show KeyServerException;

class KeyServerError extends BullException {
  final KeyServerErrorType type;

  KeyServerError(super.message, this.type);

  KeyServerError._({required String message, required this.type})
    : super(message);

  factory KeyServerError.fromException(KeyServerException e) {
    if (e.code == 401) {
      return KeyServerError._(
        message:
            'Wrong password for this backup file. Please check your password.',
        type: KeyServerErrorType.invalidCredentials,
      );
    } else if (e.code == 429) {
      final cooldownEnd = e.requestedAt?.add(
        Duration(minutes: e.cooldownInMinutes!),
      );
      final retryIn = cooldownEnd?.difference(DateTime.now());

      return KeyServerError._(
        message:
            retryIn != null
                ? 'Rate-limited. Retry in ${retryIn.inMinutes == 0 ? "${retryIn.inSeconds} seconds" : "${retryIn.inMinutes} minutes"} '
                : 'Rate-limited. Try again later',
        type: KeyServerErrorType.rateLimited,
      );
    } else if (e.code != null && e.code! >= 400 && e.code! < 500) {
      return KeyServerError._(
        message: 'Rejected by the Key Server',
        type: KeyServerErrorType.rejected,
      );
    }
    return KeyServerError._(
      message: 'Service unavailable. Please check your connection.',
      type: KeyServerErrorType.unavailable,
    );
  }

  KeyServerError.failedToConnect()
    : this._(
        message:
            'Failed to connect to the target key server. Please try again later!',
        type: KeyServerErrorType.unavailable,
      );
  KeyServerError.invalidBackupFile()
    : this._(
        message: 'Invalid backup file format',
        type: KeyServerErrorType.invalidBackupFile,
      );

  KeyServerError.commonPassword()
    : this._(
        message: 'Password is too common',
        type: KeyServerErrorType.commonPassword,
      );

  KeyServerError.keyMismatch()
    : this._(
        message: 'Backup key is not derived from default wallet',
        type: KeyServerErrorType.keyMismatch,
      );

  KeyServerError.missingPath()
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
