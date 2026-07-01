import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/widgets.dart';

enum LightningAddressErrorKind {
  invalidNym,
  invalidRegistrationInput,
  network,
  timeout,
  serverRejectedRequest,
  invalidServerResponse,
  signingFailed,
  unexpected,
}

sealed class LightningAddressException implements Exception {
  final LightningAddressErrorKind kind;
  final String code;
  final bool retryable;

  const LightningAddressException._({
    required this.kind,
    required this.code,
    required this.retryable,
  });

  const factory LightningAddressException.invalidNym() =
      LightningAddressInvalidNymException;

  const factory LightningAddressException.invalidRegistrationInput({
    required String code,
    required bool retryable,
  }) = LightningAddressInvalidRegistrationInputException;

  const factory LightningAddressException.unexpected() =
      LightningAddressUnexpectedException;

  String toTranslated(BuildContext context) => switch (kind) {
    LightningAddressErrorKind.invalidNym =>
      context.loc.lightningAddressInvalidNymError,
    LightningAddressErrorKind.invalidRegistrationInput =>
      context.loc.lightningAddressInvalidRegistrationInputError,
    LightningAddressErrorKind.network =>
      context.loc.mempoolErrorConnectionFailed,
    LightningAddressErrorKind.timeout =>
      context.loc.mempoolErrorConnectionFailed,
    LightningAddressErrorKind.serverRejectedRequest when retryable =>
      context.loc.mempoolErrorServerUnavailable,
    LightningAddressErrorKind.serverRejectedRequest =>
      context.loc.mempoolErrorServerError,
    LightningAddressErrorKind.invalidServerResponse ||
    LightningAddressErrorKind.signingFailed ||
    LightningAddressErrorKind.unexpected => context.loc.mempoolErrorUnexpected,
  };

  @override
  String toString() => 'LightningAddressException($code)';
}

final class LightningAddressInvalidNymException
    extends LightningAddressException {
  const LightningAddressInvalidNymException()
    : super._(
        kind: LightningAddressErrorKind.invalidNym,
        code: 'InvalidNym',
        retryable: false,
      );
}

final class LightningAddressInvalidRegistrationInputException
    extends LightningAddressException {
  const LightningAddressInvalidRegistrationInputException({
    required super.code,
    required super.retryable,
  }) : super._(kind: LightningAddressErrorKind.invalidRegistrationInput);
}

final class LightningAddressNetworkException extends LightningAddressException {
  const LightningAddressNetworkException({
    required super.code,
    required super.retryable,
  }) : super._(kind: LightningAddressErrorKind.network);
}

final class LightningAddressTimeoutException extends LightningAddressException {
  const LightningAddressTimeoutException({
    required super.code,
    required super.retryable,
  }) : super._(kind: LightningAddressErrorKind.timeout);
}

final class LightningAddressServerRejectedRequestException
    extends LightningAddressException {
  const LightningAddressServerRejectedRequestException({
    required super.code,
    required super.retryable,
  }) : super._(kind: LightningAddressErrorKind.serverRejectedRequest);
}

final class LightningAddressInvalidServerResponseException
    extends LightningAddressException {
  const LightningAddressInvalidServerResponseException({
    required super.code,
    required super.retryable,
  }) : super._(kind: LightningAddressErrorKind.invalidServerResponse);
}

final class LightningAddressSigningFailedException
    extends LightningAddressException {
  const LightningAddressSigningFailedException({
    required super.code,
    required super.retryable,
  }) : super._(kind: LightningAddressErrorKind.signingFailed);
}

final class LightningAddressUnexpectedException
    extends LightningAddressException {
  const LightningAddressUnexpectedException()
    : super._(
        kind: LightningAddressErrorKind.unexpected,
        code: 'Unexpected',
        retryable: false,
      );
}
