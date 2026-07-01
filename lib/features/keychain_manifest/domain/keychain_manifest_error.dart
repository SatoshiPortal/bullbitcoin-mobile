import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/widgets.dart';

enum KeychainManifestExceptionType {
  invalidEntry,
  reservationMismatch,
  conflict,
  duplicate,
  generic,
}

sealed class KeychainManifestException extends BullException {
  final KeychainManifestExceptionType type;
  final Object? cause;

  KeychainManifestException._(this.type, super.message, {this.cause});

  factory KeychainManifestException.fromInternal(Object error) {
    return switch (error) {
      KeychainManifestException() => error,
      _ => KeychainManifestGenericException(cause: error),
    };
  }

  String toTranslated(BuildContext context) {
    return context.loc.keychainManifestGenericError;
  }
}

final class KeychainManifestInvalidEntryException
    extends KeychainManifestException {
  KeychainManifestInvalidEntryException(String message)
    : super._(KeychainManifestExceptionType.invalidEntry, message);
}

final class KeychainManifestReservationMismatchException
    extends KeychainManifestException {
  KeychainManifestReservationMismatchException(String message)
    : super._(KeychainManifestExceptionType.reservationMismatch, message);
}

final class KeychainManifestEntryConflictException
    extends KeychainManifestException {
  KeychainManifestEntryConflictException(String message, {Object? cause})
    : super._(KeychainManifestExceptionType.conflict, message, cause: cause);
}

final class KeychainManifestDuplicateException
    extends KeychainManifestException {
  KeychainManifestDuplicateException(String message, {Object? cause})
    : super._(KeychainManifestExceptionType.duplicate, message, cause: cause);
}

final class KeychainManifestGenericException extends KeychainManifestException {
  KeychainManifestGenericException({Object? cause})
    : super._(
        KeychainManifestExceptionType.generic,
        'keychain manifest operation failed',
        cause: cause,
      );
}
