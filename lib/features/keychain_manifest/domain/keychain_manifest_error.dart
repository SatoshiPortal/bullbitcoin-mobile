import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/widgets.dart';

enum KeychainManifestExceptionType {
  invalidEntry,
  emptyInventory,
  fileParse,
  unsupportedFileVersion,
  reservationMismatch,
  conflict,
  duplicate,
  generic,
}

enum KeychainManifestFileParseFailureReason {
  malformedFile,
  wrongParentFingerprint,
  unknownReservation,
  invalidMetadata,
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
    return switch (this) {
      KeychainManifestUnsupportedVersionException() =>
        context.loc.keychainManifestUnsupportedFileError,
      KeychainManifestFileParseException(reason: final reason) =>
        switch (reason) {
          KeychainManifestFileParseFailureReason.malformedFile =>
            context.loc.keychainManifestMalformedFileError,
          KeychainManifestFileParseFailureReason.wrongParentFingerprint =>
            context.loc.keychainManifestWrongWalletFileError,
          KeychainManifestFileParseFailureReason.unknownReservation =>
            context.loc.keychainManifestIncompatibleFileError,
          KeychainManifestFileParseFailureReason.invalidMetadata =>
            context.loc.keychainManifestInvalidFileError,
        },
      _ => context.loc.keychainManifestGenericError,
    };
  }
}

final class KeychainManifestInvalidEntryException
    extends KeychainManifestException {
  KeychainManifestInvalidEntryException(String message)
    : super._(KeychainManifestExceptionType.invalidEntry, message);
}

final class KeychainManifestEmptyInventoryException
    extends KeychainManifestException {
  KeychainManifestEmptyInventoryException()
    : super._(
        KeychainManifestExceptionType.emptyInventory,
        'keychain manifest inventory is empty',
      );
}

final class KeychainManifestFileParseException
    extends KeychainManifestException {
  final KeychainManifestFileParseFailureReason reason;

  KeychainManifestFileParseException({required this.reason, Object? cause})
    : super._(
        KeychainManifestExceptionType.fileParse,
        'keychain manifest file parse failed',
        cause: cause,
      );
}

final class KeychainManifestUnsupportedVersionException
    extends KeychainManifestException {
  final int version;

  KeychainManifestUnsupportedVersionException(this.version)
    : super._(
        KeychainManifestExceptionType.unsupportedFileVersion,
        'unsupported keychain manifest file version',
      );
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
