import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:flutter/widgets.dart';

enum PaymentPageErrorKind {
  invalidInput,
  aliasTaken,
  aliasAlreadyAssigned,
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

sealed class PaymentPageException implements Exception {
  final PaymentPageErrorKind kind;
  final String code;
  final bool retryable;
  final String? ownedAlias;

  const PaymentPageException._({
    required this.kind,
    required this.code,
    required this.retryable,
    this.ownedAlias,
  });

  const factory PaymentPageException.invalidInput({required String code}) =
      PaymentPageInvalidInputException;

  const factory PaymentPageException.aliasTaken() =
      PaymentPageAliasTakenException;

  const factory PaymentPageException.aliasAlreadyAssigned({
    required String ownedAlias,
  }) = PaymentPageAliasAlreadyAssignedException;

  const factory PaymentPageException.noNym() = PaymentPageNoNymException;

  const factory PaymentPageException.noDefaultBitcoinWallet() =
      PaymentPageNoDefaultBitcoinWalletException;

  const factory PaymentPageException.localPreparationFailed({
    required String code,
    required bool retryable,
  }) = PaymentPageLocalPreparationFailedException;

  const factory PaymentPageException.network() = PaymentPageNetworkException;

  const factory PaymentPageException.timeout() = PaymentPageTimeoutException;

  const factory PaymentPageException.notFound() = PaymentPageNotFoundException;

  const factory PaymentPageException.rejected({required String code}) =
      PaymentPageRejectedException;

  const factory PaymentPageException.authError() = PaymentPageAuthException;

  const factory PaymentPageException.server({required bool retryable}) =
      PaymentPageServerException;

  const factory PaymentPageException.invalidServerResponse() =
      PaymentPageInvalidServerResponseException;

  const factory PaymentPageException.signingFailed() =
      PaymentPageSigningFailedException;

  const factory PaymentPageException.unexpected() =
      PaymentPageUnexpectedException;

  /// Map a shared-client [BullnymFailure] to the payment_page family. The
  /// server `reason` string is diagnostic-only and never surfaced to the user
  /// (charter C3); only the stable `code` drives the mapping.
  factory PaymentPageException.fromBullnym(BullnymFailure failure) {
    return switch (failure.kind) {
      BullnymFailureKind.invalidInput => PaymentPageException.invalidInput(
        code: failure.code,
      ),
      BullnymFailureKind.network => const PaymentPageException.network(),
      BullnymFailureKind.timeout => const PaymentPageException.timeout(),
      BullnymFailureKind.serverRejectedRequest => switch (failure.code) {
        'DonationPageNotFound' => const PaymentPageException.notFound(),
        'NameTaken' => const PaymentPageException.aliasTaken(),
        'AliasAlreadyAssigned' => switch (failure.ownedNameDetails) {
          BullnymOwnedAliasDetails(:final alias) =>
            PaymentPageException.aliasAlreadyAssigned(ownedAlias: alias.value),
          _ => const PaymentPageException.invalidServerResponse(),
        },
        'DonationPageInvalid' => PaymentPageException.rejected(
          code: failure.code,
        ),
        'AuthError' => const PaymentPageException.authError(),
        _ =>
          failure.retryable
              ? const PaymentPageException.server(retryable: true)
              : PaymentPageException.rejected(code: failure.code),
      },
      BullnymFailureKind.unexpectedHttpStatus ||
      BullnymFailureKind.emptyResponse ||
      BullnymFailureKind.invalidServerResponse =>
        const PaymentPageException.invalidServerResponse(),
      BullnymFailureKind.signingFailed =>
        const PaymentPageException.signingFailed(),
      BullnymFailureKind.unexpected => const PaymentPageException.unexpected(),
    };
  }

  String toTranslated(BuildContext context) => switch (kind) {
    PaymentPageErrorKind.invalidInput =>
      context.loc.paymentPageErrorInvalidInput,
    PaymentPageErrorKind.aliasTaken => context.loc.paymentPageAliasTaken,
    PaymentPageErrorKind.aliasAlreadyAssigned =>
      context.loc.paymentPageAliasAlreadyAssigned,
    PaymentPageErrorKind.noNym => context.loc.paymentPageErrorNoNym,
    PaymentPageErrorKind.noDefaultBitcoinWallet =>
      context.loc.paymentPageErrorNoDefaultWallet,
    PaymentPageErrorKind.localPreparationFailed =>
      context.loc.paymentPageErrorSetupFailed,
    PaymentPageErrorKind.network => context.loc.paymentPageErrorConnection,
    PaymentPageErrorKind.timeout => context.loc.paymentPageErrorConnection,
    PaymentPageErrorKind.notFound => context.loc.paymentPageErrorNotFound,
    PaymentPageErrorKind.rejected => context.loc.paymentPageErrorRejected,
    PaymentPageErrorKind.authError => context.loc.paymentPageErrorAuth,
    PaymentPageErrorKind.server => context.loc.paymentPageErrorServer,
    PaymentPageErrorKind.invalidServerResponse ||
    PaymentPageErrorKind.signingFailed ||
    PaymentPageErrorKind.unexpected => context.loc.paymentPageErrorUnexpected,
  };

  @override
  String toString() => 'PaymentPageException($code)';
}

final class PaymentPageInvalidInputException extends PaymentPageException {
  const PaymentPageInvalidInputException({required super.code})
    : super._(kind: PaymentPageErrorKind.invalidInput, retryable: false);
}

final class PaymentPageAliasTakenException extends PaymentPageException {
  const PaymentPageAliasTakenException()
    : super._(
        kind: PaymentPageErrorKind.aliasTaken,
        code: 'NameTaken',
        retryable: false,
      );
}

final class PaymentPageAliasAlreadyAssignedException
    extends PaymentPageException {
  const PaymentPageAliasAlreadyAssignedException({required super.ownedAlias})
    : super._(
        kind: PaymentPageErrorKind.aliasAlreadyAssigned,
        code: 'AliasAlreadyAssigned',
        retryable: false,
      );
}

final class PaymentPageNoNymException extends PaymentPageException {
  const PaymentPageNoNymException()
    : super._(
        kind: PaymentPageErrorKind.noNym,
        code: 'NoNym',
        retryable: false,
      );
}

final class PaymentPageNoDefaultBitcoinWalletException
    extends PaymentPageException {
  const PaymentPageNoDefaultBitcoinWalletException()
    : super._(
        kind: PaymentPageErrorKind.noDefaultBitcoinWallet,
        code: 'NoDefaultBitcoinWallet',
        retryable: false,
      );
}

final class PaymentPageLocalPreparationFailedException
    extends PaymentPageException {
  const PaymentPageLocalPreparationFailedException({
    required super.code,
    required super.retryable,
  }) : super._(kind: PaymentPageErrorKind.localPreparationFailed);
}

final class PaymentPageNetworkException extends PaymentPageException {
  const PaymentPageNetworkException()
    : super._(
        kind: PaymentPageErrorKind.network,
        code: 'NetworkError',
        retryable: true,
      );
}

final class PaymentPageTimeoutException extends PaymentPageException {
  const PaymentPageTimeoutException()
    : super._(
        kind: PaymentPageErrorKind.timeout,
        code: 'Timeout',
        retryable: true,
      );
}

final class PaymentPageNotFoundException extends PaymentPageException {
  const PaymentPageNotFoundException()
    : super._(
        kind: PaymentPageErrorKind.notFound,
        code: 'DonationPageNotFound',
        retryable: false,
      );
}

final class PaymentPageRejectedException extends PaymentPageException {
  const PaymentPageRejectedException({required super.code})
    : super._(kind: PaymentPageErrorKind.rejected, retryable: false);
}

final class PaymentPageAuthException extends PaymentPageException {
  const PaymentPageAuthException()
    : super._(
        kind: PaymentPageErrorKind.authError,
        code: 'AuthError',
        retryable: false,
      );
}

final class PaymentPageServerException extends PaymentPageException {
  const PaymentPageServerException({required super.retryable})
    : super._(kind: PaymentPageErrorKind.server, code: 'ServerError');
}

final class PaymentPageInvalidServerResponseException
    extends PaymentPageException {
  const PaymentPageInvalidServerResponseException()
    : super._(
        kind: PaymentPageErrorKind.invalidServerResponse,
        code: 'InvalidServerResponse',
        retryable: true,
      );
}

final class PaymentPageSigningFailedException extends PaymentPageException {
  const PaymentPageSigningFailedException()
    : super._(
        kind: PaymentPageErrorKind.signingFailed,
        code: 'SigningFailed',
        retryable: false,
      );
}

final class PaymentPageUnexpectedException extends PaymentPageException {
  const PaymentPageUnexpectedException()
    : super._(
        kind: PaymentPageErrorKind.unexpected,
        code: 'Unexpected',
        retryable: false,
      );
}

/// Which phase of the save orchestration failed. Pre-commitment (local
/// preparation: nym resolve, xprv derive, wallet prepare) is fatal/retryable
/// with the wallet rollback rule; submission (the signed PUT) may have reached
/// the server on a transport failure.
enum PaymentPageSaveFailurePhase { localPreparation, submission }

bool _isPaymentPageSubmissionUncertain(PaymentPageException cause) {
  return switch (cause.kind) {
    PaymentPageErrorKind.network ||
    PaymentPageErrorKind.timeout ||
    PaymentPageErrorKind.server ||
    PaymentPageErrorKind.invalidServerResponse => true,
    PaymentPageErrorKind.invalidInput ||
    PaymentPageErrorKind.aliasTaken ||
    PaymentPageErrorKind.aliasAlreadyAssigned ||
    PaymentPageErrorKind.noNym ||
    PaymentPageErrorKind.noDefaultBitcoinWallet ||
    PaymentPageErrorKind.localPreparationFailed ||
    PaymentPageErrorKind.notFound ||
    PaymentPageErrorKind.rejected ||
    PaymentPageErrorKind.authError ||
    PaymentPageErrorKind.signingFailed ||
    PaymentPageErrorKind.unexpected => false,
  };
}

/// Two-phase wrapper for the save orchestration (the LA precedent). Carries the
/// [cause] and whether a submission-phase failure might have reached the server
/// (retry is a benign idempotent upsert — §7.4).
final class PaymentPageSaveException extends PaymentPageException {
  final PaymentPageSaveFailurePhase phase;
  final PaymentPageException cause;
  final bool submissionMayBeUncertain;

  PaymentPageSaveException.localPreparation({required this.cause})
    : phase = PaymentPageSaveFailurePhase.localPreparation,
      submissionMayBeUncertain = false,
      super._(
        kind: cause.kind,
        code: cause.code,
        retryable: cause.retryable,
        ownedAlias: cause.ownedAlias,
      );

  PaymentPageSaveException.submission({required this.cause})
    : phase = PaymentPageSaveFailurePhase.submission,
      submissionMayBeUncertain = _isPaymentPageSubmissionUncertain(cause),
      super._(
        kind: cause.kind,
        code: cause.code,
        retryable: cause.retryable,
        ownedAlias: cause.ownedAlias,
      );

  @override
  String toTranslated(BuildContext context) => cause.toTranslated(context);

  @override
  String toString() => 'PaymentPageSaveException(phase: $phase, cause: $cause)';
}
