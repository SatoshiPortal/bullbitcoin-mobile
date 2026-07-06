import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:flutter/widgets.dart';

enum PaymentPageErrorKind {
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

sealed class PaymentPageException implements Exception {
  final PaymentPageErrorKind kind;
  final String code;
  final bool retryable;

  const PaymentPageException._({
    required this.kind,
    required this.code,
    required this.retryable,
  });

  const factory PaymentPageException.invalidInput({required String code}) =
      PaymentPageInvalidInputException;

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

  /// Map a shared-client [BullnymException] to the payment_page family. The
  /// server `reason` string is diagnostic-only and never surfaced to the user
  /// (charter C3); only the stable `code` drives the mapping.
  factory PaymentPageException.fromBullnym(BullnymException error) {
    return switch (error.kind) {
      BullnymErrorKind.invalidInput => PaymentPageException.invalidInput(
        code: error.code,
      ),
      BullnymErrorKind.network => const PaymentPageException.network(),
      BullnymErrorKind.timeout => const PaymentPageException.timeout(),
      BullnymErrorKind.serverRejectedRequest => switch (error.code) {
        'DonationPageNotFound' => const PaymentPageException.notFound(),
        'DonationPageInvalid' => PaymentPageException.rejected(
          code: error.code,
        ),
        'AuthError' => const PaymentPageException.authError(),
        _ =>
          error.retryable
              ? const PaymentPageException.server(retryable: true)
              : PaymentPageException.rejected(code: error.code),
      },
      BullnymErrorKind.unexpectedHttpStatus ||
      BullnymErrorKind.emptyResponse ||
      BullnymErrorKind.invalidServerResponse =>
        const PaymentPageException.invalidServerResponse(),
      BullnymErrorKind.signingFailed =>
        const PaymentPageException.signingFailed(),
    };
  }

  String toTranslated(BuildContext context) => switch (kind) {
    PaymentPageErrorKind.invalidInput =>
      context.loc.paymentPageErrorInvalidInput,
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
    PaymentPageErrorKind.unexpected =>
      context.loc.paymentPageErrorUnexpected,
  };

  @override
  String toString() => 'PaymentPageException($code)';
}

final class PaymentPageInvalidInputException extends PaymentPageException {
  const PaymentPageInvalidInputException({required super.code})
    : super._(kind: PaymentPageErrorKind.invalidInput, retryable: false);
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
