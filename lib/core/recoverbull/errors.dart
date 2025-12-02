import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:recoverbull/recoverbull.dart';

class RecoverBullError extends BullException {
  RecoverBullError(super.message);
}

class ServerError extends RecoverBullError {
  ServerError(super.message);

  static ServerError fromException(KeyServerException e) {
    if (e.code == 401) {
      return InvalidCredentialsError();
    } else if (e.code == 429) {
      final cooldownEnd = e.requestedAt?.add(
        Duration(minutes: e.cooldownInMinutes!),
      );
      final retryIn = cooldownEnd?.difference(DateTime.now());
      return RateLimitedError(retryIn: retryIn ?? Duration.zero);
    } else if (e.code != null && e.code! >= 400 && e.code! < 500) {
      return KeyServerErrorRejected();
    }
    return KeyServerErrorServiceUnavailable();
  }
}

class InvalidCredentialsError extends ServerError {
  InvalidCredentialsError()
    : super('Wrong password for this backup file. Please check your password.');
}

class RateLimitedError extends ServerError {
  final Duration retryIn;

  RateLimitedError({required this.retryIn})
    : super(
        'Rate-limited. Retry in ${retryIn.inMinutes == 0 ? "${retryIn.inSeconds} seconds" : "${retryIn.inMinutes} minutes"} ',
      );
}

class KeyServerErrorRejected extends ServerError {
  KeyServerErrorRejected() : super('Rejected by the Key Server');
}

class KeyServerErrorServiceUnavailable extends ServerError {
  KeyServerErrorServiceUnavailable()
    : super('Service unavailable. Please check your connection.');
}

class InvalidVaultFileError extends BullException {
  InvalidVaultFileError() : super('Invalid vault file.');
}
