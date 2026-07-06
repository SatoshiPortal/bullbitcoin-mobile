import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:flutter/widgets.dart';

enum PosErrorKind {
  invalidInput,
  noNym,
  noDefaultBitcoinWallet,
  localPreparationFailed,
  network,
  timeout,
  notFound,
  rejected,
  authError,
  server,
  invalidServerResponse,
  signingFailed,
  unexpected,
}

sealed class PosException implements Exception {
  final PosErrorKind kind;
  final String code;
  final bool retryable;

  const PosException._({
    required this.kind,
    required this.code,
    required this.retryable,
  });

  const factory PosException.invalidInput({required String code}) =
      PosInvalidInputException;

  const factory PosException.noNym() = PosNoNymException;

  const factory PosException.noDefaultBitcoinWallet() =
      PosNoDefaultBitcoinWalletException;

  const factory PosException.localPreparationFailed({
    required String code,
    required bool retryable,
  }) = PosLocalPreparationFailedException;

  const factory PosException.network() = PosNetworkException;

  const factory PosException.timeout() = PosTimeoutException;

  const factory PosException.notFound() = PosNotFoundException;

  const factory PosException.rejected({required String code}) =
      PosRejectedException;

  const factory PosException.authError() = PosAuthException;

  const factory PosException.server({required bool retryable}) =
      PosServerException;

  const factory PosException.invalidServerResponse() =
      PosInvalidServerResponseException;

  const factory PosException.signingFailed() = PosSigningFailedException;

  const factory PosException.unexpected() = PosUnexpectedException;

  /// Map a shared-client [BullnymException] to the pos family. The server
  /// `reason` string is diagnostic-only and never surfaced to the user (charter
  /// C3); only the stable `code` drives the mapping. A descriptorless kind=pos
  /// save is hard-rejected by the server as `DonationPageInvalid` (KR-1, no
  /// LA-cursor fallback), which lands here as `rejected`.
  factory PosException.fromBullnym(BullnymException error) {
    return switch (error.kind) {
      BullnymErrorKind.invalidInput => PosException.invalidInput(
        code: error.code,
      ),
      BullnymErrorKind.network => const PosException.network(),
      BullnymErrorKind.timeout => const PosException.timeout(),
      BullnymErrorKind.serverRejectedRequest => switch (error.code) {
        'DonationPageNotFound' => const PosException.notFound(),
        'DonationPageInvalid' => PosException.rejected(code: error.code),
        'AuthError' => const PosException.authError(),
        _ =>
          error.retryable
              ? const PosException.server(retryable: true)
              : PosException.rejected(code: error.code),
      },
      BullnymErrorKind.unexpectedHttpStatus ||
      BullnymErrorKind.emptyResponse ||
      BullnymErrorKind.invalidServerResponse =>
        const PosException.invalidServerResponse(),
      BullnymErrorKind.signingFailed => const PosException.signingFailed(),
    };
  }

  String toTranslated(BuildContext context) => switch (kind) {
    PosErrorKind.invalidInput => context.loc.posErrorInvalidInput,
    PosErrorKind.noNym => context.loc.posErrorNoNym,
    PosErrorKind.noDefaultBitcoinWallet => context.loc.posErrorNoDefaultWallet,
    PosErrorKind.localPreparationFailed => context.loc.posErrorSetupFailed,
    PosErrorKind.network => context.loc.posErrorConnection,
    PosErrorKind.timeout => context.loc.posErrorConnection,
    PosErrorKind.notFound => context.loc.posErrorNotFound,
    PosErrorKind.rejected => context.loc.posErrorRejected,
    PosErrorKind.authError => context.loc.posErrorAuth,
    PosErrorKind.server => context.loc.posErrorServer,
    PosErrorKind.invalidServerResponse ||
    PosErrorKind.signingFailed ||
    PosErrorKind.unexpected => context.loc.posErrorUnexpected,
  };

  @override
  String toString() => 'PosException($code)';
}

final class PosInvalidInputException extends PosException {
  const PosInvalidInputException({required super.code})
    : super._(kind: PosErrorKind.invalidInput, retryable: false);
}

final class PosNoNymException extends PosException {
  const PosNoNymException()
    : super._(kind: PosErrorKind.noNym, code: 'NoNym', retryable: false);
}

final class PosNoDefaultBitcoinWalletException extends PosException {
  const PosNoDefaultBitcoinWalletException()
    : super._(
        kind: PosErrorKind.noDefaultBitcoinWallet,
        code: 'NoDefaultBitcoinWallet',
        retryable: false,
      );
}

final class PosLocalPreparationFailedException extends PosException {
  const PosLocalPreparationFailedException({
    required super.code,
    required super.retryable,
  }) : super._(kind: PosErrorKind.localPreparationFailed);
}

final class PosNetworkException extends PosException {
  const PosNetworkException()
    : super._(kind: PosErrorKind.network, code: 'NetworkError', retryable: true);
}

final class PosTimeoutException extends PosException {
  const PosTimeoutException()
    : super._(kind: PosErrorKind.timeout, code: 'Timeout', retryable: true);
}

final class PosNotFoundException extends PosException {
  const PosNotFoundException()
    : super._(
        kind: PosErrorKind.notFound,
        code: 'DonationPageNotFound',
        retryable: false,
      );
}

final class PosRejectedException extends PosException {
  const PosRejectedException({required super.code})
    : super._(kind: PosErrorKind.rejected, retryable: false);
}

final class PosAuthException extends PosException {
  const PosAuthException()
    : super._(
        kind: PosErrorKind.authError,
        code: 'AuthError',
        retryable: false,
      );
}

final class PosServerException extends PosException {
  const PosServerException({required super.retryable})
    : super._(kind: PosErrorKind.server, code: 'ServerError');
}

final class PosInvalidServerResponseException extends PosException {
  const PosInvalidServerResponseException()
    : super._(
        kind: PosErrorKind.invalidServerResponse,
        code: 'InvalidServerResponse',
        retryable: true,
      );
}

final class PosSigningFailedException extends PosException {
  const PosSigningFailedException()
    : super._(
        kind: PosErrorKind.signingFailed,
        code: 'SigningFailed',
        retryable: false,
      );
}

final class PosUnexpectedException extends PosException {
  const PosUnexpectedException()
    : super._(
        kind: PosErrorKind.unexpected,
        code: 'Unexpected',
        retryable: false,
      );
}

/// Which phase of the provision orchestration failed. Pre-commitment (local
/// preparation: nym resolve, xprv derive, wallet prepare) is fatal/retryable
/// with the wallet rollback rule; submission (the signed PUT) may have reached
/// the server on a transport failure.
enum PosProvisionFailurePhase { localPreparation, submission }

bool _isPosSubmissionUncertain(PosException cause) {
  return switch (cause.kind) {
    PosErrorKind.network ||
    PosErrorKind.timeout ||
    PosErrorKind.server ||
    PosErrorKind.invalidServerResponse => true,
    PosErrorKind.invalidInput ||
    PosErrorKind.noNym ||
    PosErrorKind.noDefaultBitcoinWallet ||
    PosErrorKind.localPreparationFailed ||
    PosErrorKind.notFound ||
    PosErrorKind.rejected ||
    PosErrorKind.authError ||
    PosErrorKind.signingFailed ||
    PosErrorKind.unexpected => false,
  };
}

/// Two-phase wrapper for the provision orchestration (the page precedent).
/// Carries the [cause] and whether a submission-phase failure might have reached
/// the server (retry is a benign idempotent upsert - §7.7).
final class PosProvisionException extends PosException {
  final PosProvisionFailurePhase phase;
  final PosException cause;
  final bool submissionMayBeUncertain;

  PosProvisionException.localPreparation({required this.cause})
    : phase = PosProvisionFailurePhase.localPreparation,
      submissionMayBeUncertain = false,
      super._(kind: cause.kind, code: cause.code, retryable: cause.retryable);

  PosProvisionException.submission({required this.cause})
    : phase = PosProvisionFailurePhase.submission,
      submissionMayBeUncertain = _isPosSubmissionUncertain(cause),
      super._(kind: cause.kind, code: cause.code, retryable: cause.retryable);

  @override
  String toTranslated(BuildContext context) => cause.toTranslated(context);

  @override
  String toString() => 'PosProvisionException(phase: $phase, cause: $cause)';
}
