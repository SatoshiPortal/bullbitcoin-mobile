import 'package:bb_mobile/core_deprecated/errors/bull_exception.dart';
import 'package:bb_mobile/core_deprecated/utils/build_context_x.dart';
import 'package:flutter/material.dart';
import 'package:recoverbull/recoverbull.dart';

class RecoverBullError extends BullException {
  RecoverBullError(super.message);

  /// Returns the localized error message.
  String toTranslated(BuildContext context) => message;
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
  InvalidCredentialsError() : super('InvalidCredentialsError');

  @override
  String toTranslated(BuildContext context) =>
      context.loc.recoverbullErrorInvalidCredentials;
}

class RateLimitedError extends ServerError {
  final Duration retryIn;

  RateLimitedError({required this.retryIn}) : super('RateLimitedError');

  @override
  String toTranslated(BuildContext context) {
    final seconds = retryIn.inSeconds;
    final minutes = retryIn.inMinutes;

    final String formattedTime;
    if (seconds < 60) {
      formattedTime = context.loc.durationSeconds(seconds.toString());
    } else {
      formattedTime =
          minutes == 1
              ? context.loc.durationMinute(minutes.toString())
              : context.loc.durationMinutes(minutes.toString());
    }

    return context.loc.recoverbullErrorRateLimited(formattedTime);
  }
}

class KeyServerErrorRejected extends ServerError {
  KeyServerErrorRejected() : super('KeyServerErrorRejected');

  @override
  String toTranslated(BuildContext context) =>
      context.loc.recoverbullErrorRejected;
}

class KeyServerErrorServiceUnavailable extends ServerError {
  KeyServerErrorServiceUnavailable() : super('KeyServerErrorServiceUnavailable');

  @override
  String toTranslated(BuildContext context) =>
      context.loc.recoverbullErrorServiceUnavailable;
}

class InvalidVaultFileError extends BullException {
  InvalidVaultFileError() : super('InvalidVaultFileError');

  /// Returns the localized error message.
  String toTranslated(BuildContext context) =>
      context.loc.recoverbullErrorInvalidVaultFile;
}
