import 'package:bb_mobile/core/failures/failure.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_public_names.dart';

enum BullnymFailureKind {
  invalidInput,
  network,
  timeout,
  serverRejectedRequest,
  unexpectedHttpStatus,
  emptyResponse,
  invalidServerResponse,
  signingFailed,
  unexpected,
}

/// Closed set of recoverable failures exposed by the Bullnym boundary.
///
/// [logMessage] is diagnostic-only. Presentation renders each variant through
/// the exhaustive `bullnym_failure_l10n.dart` extension and never displays it.
sealed class BullnymFailure extends Failure {
  final BullnymFailureKind kind;
  final String code;
  final int? statusCode;
  final bool retryable;
  final BullnymOwnedNameDetails? ownedNameDetails;

  const BullnymFailure._({
    required this.kind,
    required this.code,
    this.statusCode,
    required this.retryable,
    this.ownedNameDetails,
    String? logMessage,
  }) : super(logMessage);

  const factory BullnymFailure.invalidInput(String logMessage) =
      BullnymInvalidInputFailure;

  const factory BullnymFailure.network({required String logMessage}) =
      BullnymNetworkFailure;

  const factory BullnymFailure.timeout({required String logMessage}) =
      BullnymTimeoutFailure;

  const factory BullnymFailure.serverRejectedRequest({
    required String code,
    required String logMessage,
    int? statusCode,
    required bool retryable,
    BullnymOwnedNameDetails? ownedNameDetails,
  }) = BullnymServerRejectedRequestFailure;

  const factory BullnymFailure.unexpectedHttpStatus({int? statusCode}) =
      BullnymUnexpectedHttpStatusFailure;

  const factory BullnymFailure.emptyResponse({int? statusCode}) =
      BullnymEmptyResponseFailure;

  const factory BullnymFailure.invalidServerResponse({
    String logMessage,
    int? statusCode,
  }) = BullnymInvalidServerResponseFailure;

  const factory BullnymFailure.signingFailed() = BullnymSigningFailedFailure;

  const factory BullnymFailure.unexpected([String? logMessage]) =
      BullnymUnexpectedFailure;

  @override
  String toString() => 'BullnymFailure($code)';
}

final class BullnymInvalidInputFailure extends BullnymFailure {
  const BullnymInvalidInputFailure(String logMessage)
    : super._(
        kind: BullnymFailureKind.invalidInput,
        code: 'InvalidInput',
        retryable: false,
        logMessage: logMessage,
      );
}

final class BullnymNetworkFailure extends BullnymFailure {
  const BullnymNetworkFailure({required String logMessage})
    : super._(
        kind: BullnymFailureKind.network,
        code: 'NetworkError',
        retryable: true,
        logMessage: logMessage,
      );
}

final class BullnymTimeoutFailure extends BullnymFailure {
  const BullnymTimeoutFailure({required String logMessage})
    : super._(
        kind: BullnymFailureKind.timeout,
        code: 'Timeout',
        retryable: true,
        logMessage: logMessage,
      );
}

final class BullnymServerRejectedRequestFailure extends BullnymFailure {
  const BullnymServerRejectedRequestFailure({
    required super.code,
    required String logMessage,
    super.statusCode,
    required super.retryable,
    super.ownedNameDetails,
  }) : super._(
         kind: BullnymFailureKind.serverRejectedRequest,
         logMessage: logMessage,
       );
}

final class BullnymUnexpectedHttpStatusFailure extends BullnymFailure {
  const BullnymUnexpectedHttpStatusFailure({super.statusCode})
    : super._(
        kind: BullnymFailureKind.unexpectedHttpStatus,
        code: 'HttpError',
        retryable: true,
        logMessage: 'Unexpected server response',
      );
}

final class BullnymEmptyResponseFailure extends BullnymFailure {
  const BullnymEmptyResponseFailure({super.statusCode})
    : super._(
        kind: BullnymFailureKind.emptyResponse,
        code: 'EmptyResponse',
        retryable: true,
        logMessage: 'Server returned an empty response',
      );
}

final class BullnymInvalidServerResponseFailure extends BullnymFailure {
  const BullnymInvalidServerResponseFailure({
    String logMessage = 'Invalid Bullnym server response',
    super.statusCode,
  }) : super._(
         kind: BullnymFailureKind.invalidServerResponse,
         code: 'InvalidServerResponse',
         retryable: true,
         logMessage: logMessage,
       );
}

final class BullnymSigningFailedFailure extends BullnymFailure {
  const BullnymSigningFailedFailure()
    : super._(
        kind: BullnymFailureKind.signingFailed,
        code: 'SigningFailed',
        retryable: false,
        logMessage: 'Bullnym request signing failed',
      );
}

final class BullnymUnexpectedFailure extends BullnymFailure {
  const BullnymUnexpectedFailure([String? logMessage])
    : super._(
        kind: BullnymFailureKind.unexpected,
        code: 'Unexpected',
        retryable: false,
        logMessage: logMessage,
      );
}
