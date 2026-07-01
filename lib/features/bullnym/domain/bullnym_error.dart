import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/widgets.dart';

enum BullnymErrorKind {
  invalidInput,
  network,
  timeout,
  serverRejectedRequest,
  unexpectedHttpStatus,
  emptyResponse,
  invalidServerResponse,
  signingFailed,
}

sealed class BullnymException implements Exception {
  final BullnymErrorKind kind;
  final String code;
  final String diagnosticReason;
  final int? statusCode;
  final bool retryable;

  const BullnymException._({
    required this.kind,
    required this.code,
    required this.diagnosticReason,
    this.statusCode,
    required this.retryable,
  });

  const factory BullnymException.invalidInput(String diagnosticReason) =
      BullnymInvalidInputException;

  const factory BullnymException.network({required String diagnosticReason}) =
      BullnymNetworkException;

  const factory BullnymException.timeout({required String diagnosticReason}) =
      BullnymTimeoutException;

  const factory BullnymException.serverRejectedRequest({
    required String code,
    required String diagnosticReason,
    int? statusCode,
    required bool retryable,
  }) = BullnymServerRejectedRequestException;

  const factory BullnymException.unexpectedHttpStatus({int? statusCode}) =
      BullnymUnexpectedHttpStatusException;

  const factory BullnymException.emptyResponse({int? statusCode}) =
      BullnymEmptyResponseException;

  const factory BullnymException.invalidServerResponse({
    String diagnosticReason,
    int? statusCode,
  }) = BullnymInvalidServerResponseException;

  const factory BullnymException.signingFailed() =
      BullnymSigningFailedException;

  String toTranslated(BuildContext context) => switch (kind) {
    BullnymErrorKind.network => context.loc.mempoolErrorConnectionFailed,
    BullnymErrorKind.timeout => context.loc.mempoolErrorConnectionFailed,
    BullnymErrorKind.serverRejectedRequest when retryable =>
      context.loc.mempoolErrorServerUnavailable,
    BullnymErrorKind.serverRejectedRequest =>
      context.loc.mempoolErrorServerError,
    BullnymErrorKind.invalidInput ||
    BullnymErrorKind.unexpectedHttpStatus ||
    BullnymErrorKind.emptyResponse ||
    BullnymErrorKind.invalidServerResponse ||
    BullnymErrorKind.signingFailed => context.loc.mempoolErrorUnexpected,
  };

  @override
  String toString() => 'BullnymException($code)';
}

final class BullnymInvalidInputException extends BullnymException {
  const BullnymInvalidInputException(String diagnosticReason)
    : super._(
        kind: BullnymErrorKind.invalidInput,
        code: 'InvalidInput',
        diagnosticReason: diagnosticReason,
        retryable: false,
      );
}

final class BullnymNetworkException extends BullnymException {
  const BullnymNetworkException({required super.diagnosticReason})
    : super._(
        kind: BullnymErrorKind.network,
        code: 'NetworkError',
        retryable: true,
      );
}

final class BullnymTimeoutException extends BullnymException {
  const BullnymTimeoutException({required super.diagnosticReason})
    : super._(kind: BullnymErrorKind.timeout, code: 'Timeout', retryable: true);
}

final class BullnymServerRejectedRequestException extends BullnymException {
  const BullnymServerRejectedRequestException({
    required super.code,
    required super.diagnosticReason,
    super.statusCode,
    required super.retryable,
  }) : super._(kind: BullnymErrorKind.serverRejectedRequest);
}

final class BullnymUnexpectedHttpStatusException extends BullnymException {
  const BullnymUnexpectedHttpStatusException({super.statusCode})
    : super._(
        kind: BullnymErrorKind.unexpectedHttpStatus,
        code: 'HttpError',
        diagnosticReason: 'Unexpected server response',
        retryable: true,
      );
}

final class BullnymEmptyResponseException extends BullnymException {
  const BullnymEmptyResponseException({super.statusCode})
    : super._(
        kind: BullnymErrorKind.emptyResponse,
        code: 'EmptyResponse',
        diagnosticReason: 'Server returned an empty response',
        retryable: true,
      );
}

final class BullnymInvalidServerResponseException extends BullnymException {
  const BullnymInvalidServerResponseException({
    super.diagnosticReason = 'Invalid Bullnym server response',
    super.statusCode,
  }) : super._(
         kind: BullnymErrorKind.invalidServerResponse,
         code: 'InvalidServerResponse',
         retryable: true,
       );
}

final class BullnymSigningFailedException extends BullnymException {
  const BullnymSigningFailedException()
    : super._(
        kind: BullnymErrorKind.signingFailed,
        code: 'SigningFailed',
        diagnosticReason: 'Bullnym request signing failed',
        retryable: false,
      );
}
