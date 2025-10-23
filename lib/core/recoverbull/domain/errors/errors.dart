import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:recoverbull/recoverbull.dart';

class RecoverBullError extends BullException {
  RecoverBullError(super.message);
}

class KeysMismatchError extends RecoverBullError {
  KeysMismatchError() : super('Keys mismatch.');
}

class KeyServerError extends BullException {
  KeyServerError(super.message);

  static KeyServerError fromException(KeyServerException e) {
    if (e.code == 401) {
      return KeyServerErrorInvalidCredentials();
    } else if (e.code == 429) {
      final cooldownEnd = e.requestedAt?.add(
        Duration(minutes: e.cooldownInMinutes!),
      );
      final retryIn = cooldownEnd?.difference(DateTime.now());
      return KeyServerErrorRateLimited(retryIn: retryIn ?? Duration.zero);
    } else if (e.code != null && e.code! >= 400 && e.code! < 500) {
      return KeyServerErrorRejected();
    }
    return KeyServerErrorServiceUnavailable();
  }
}

class KeyServerErrorInvalidCredentials extends KeyServerError {
  KeyServerErrorInvalidCredentials()
    : super('Wrong password for this backup file. Please check your password.');
}

class KeyServerErrorRateLimited extends KeyServerError {
  KeyServerErrorRateLimited({required Duration retryIn})
    : super(
        'Rate-limited. Retry in ${retryIn.inMinutes == 0 ? "${retryIn.inSeconds} seconds" : "${retryIn.inMinutes} minutes"} ',
      );
}

class KeyServerErrorRejected extends KeyServerError {
  KeyServerErrorRejected() : super('Rejected by the Key Server');
}

class KeyServerErrorServiceUnavailable extends KeyServerError {
  KeyServerErrorServiceUnavailable()
    : super('Service unavailable. Please check your connection.');
}
