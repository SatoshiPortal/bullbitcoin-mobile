import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:flutter/widgets.dart';

enum InvoicesErrorKind {
  noDefaultBitcoinWallet,
  noDefaultLiquidWallet,
  invalidInput,
  reusedBitcoinAddress,
  reusedLiquidAddress,
  notFound,
  authError,
  rateLimited,
  network,
  timeout,
  invalidServerResponse,
  signingFailed,
  server,
  unexpected,
}

sealed class InvoicesException implements Exception {
  final InvoicesErrorKind kind;
  final String code;
  final bool retryable;

  const InvoicesException._({
    required this.kind,
    required this.code,
    required this.retryable,
  });

  const factory InvoicesException.noDefaultBitcoinWallet() =
      InvoicesNoDefaultBitcoinWalletException;

  const factory InvoicesException.noDefaultLiquidWallet() =
      InvoicesNoDefaultLiquidWalletException;

  const factory InvoicesException.invalidInput({required String code}) =
      InvoicesInvalidInputException;

  const factory InvoicesException.reusedBitcoinAddress() =
      InvoicesReusedBitcoinAddressException;

  const factory InvoicesException.reusedLiquidAddress() =
      InvoicesReusedLiquidAddressException;

  const factory InvoicesException.notFound() = InvoicesNotFoundException;

  const factory InvoicesException.authError() = InvoicesAuthException;

  const factory InvoicesException.rateLimited() = InvoicesRateLimitedException;

  const factory InvoicesException.network() = InvoicesNetworkException;

  const factory InvoicesException.timeout() = InvoicesTimeoutException;

  const factory InvoicesException.invalidServerResponse() =
      InvoicesInvalidServerResponseException;

  const factory InvoicesException.signingFailed() =
      InvoicesSigningFailedException;

  const factory InvoicesException.server({required bool retryable}) =
      InvoicesServerException;

  const factory InvoicesException.unexpected() = InvoicesUnexpectedException;

  /// Map a shared-client [BullnymException] onto the invoices family. The server
  /// `reason` string is diagnostic-only and never surfaced to the user (charter
  /// C3); only the stable `code` drives the mapping. A route-absent /
  /// feature-disabled server (`unexpectedHttpStatus`, e.g. a 404) maps to a
  /// retryable `server` error so the create FAILS CLOSED and loud (§7.12).
  factory InvoicesException.fromBullnym(BullnymException error) {
    return switch (error.kind) {
      BullnymErrorKind.invalidInput => InvoicesException.invalidInput(
        code: error.code,
      ),
      BullnymErrorKind.network => const InvoicesException.network(),
      BullnymErrorKind.timeout => const InvoicesException.timeout(),
      BullnymErrorKind.serverRejectedRequest => switch (error.code) {
        'InvoiceNotFound' => const InvoicesException.notFound(),
        'InvalidAmount' => InvoicesException.invalidInput(code: error.code),
        'AuthError' => const InvoicesException.authError(),
        'BitcoinAddressAlreadyUsed' =>
          const InvoicesException.reusedBitcoinAddress(),
        'LiquidAddressAlreadyUsed' =>
          const InvoicesException.reusedLiquidAddress(),
        'RateLimitedSender' ||
        'RateLimitedRecipient' ||
        'RateLimitedNetwork' => const InvoicesException.rateLimited(),
        _ => InvoicesException.server(retryable: error.retryable),
      },
      BullnymErrorKind.unexpectedHttpStatus =>
        const InvoicesException.server(retryable: true),
      BullnymErrorKind.emptyResponse ||
      BullnymErrorKind.invalidServerResponse =>
        const InvoicesException.invalidServerResponse(),
      BullnymErrorKind.signingFailed => const InvoicesException.signingFailed(),
    };
  }

  String toTranslated(BuildContext context) => switch (kind) {
    InvoicesErrorKind.noDefaultBitcoinWallet =>
      context.loc.invoiceErrorNoDefaultBitcoinWallet,
    InvoicesErrorKind.noDefaultLiquidWallet =>
      context.loc.invoiceErrorNoDefaultLiquidWallet,
    InvoicesErrorKind.invalidInput => context.loc.invoiceErrorInvalidInput,
    InvoicesErrorKind.reusedBitcoinAddress =>
      context.loc.invoiceErrorReusedAddress,
    InvoicesErrorKind.reusedLiquidAddress =>
      context.loc.invoiceErrorReusedAddress,
    InvoicesErrorKind.notFound => context.loc.invoiceErrorNotFound,
    InvoicesErrorKind.authError => context.loc.invoiceErrorAuth,
    InvoicesErrorKind.rateLimited => context.loc.invoiceErrorRateLimited,
    InvoicesErrorKind.network => context.loc.invoiceErrorConnection,
    InvoicesErrorKind.timeout => context.loc.invoiceErrorConnection,
    InvoicesErrorKind.server => context.loc.invoiceErrorServer,
    InvoicesErrorKind.invalidServerResponse ||
    InvoicesErrorKind.signingFailed ||
    InvoicesErrorKind.unexpected => context.loc.invoiceErrorUnexpected,
  };

  @override
  String toString() => 'InvoicesException($code)';
}

final class InvoicesNoDefaultBitcoinWalletException extends InvoicesException {
  const InvoicesNoDefaultBitcoinWalletException()
    : super._(
        kind: InvoicesErrorKind.noDefaultBitcoinWallet,
        code: 'NoDefaultBitcoinWallet',
        retryable: false,
      );
}

final class InvoicesNoDefaultLiquidWalletException extends InvoicesException {
  const InvoicesNoDefaultLiquidWalletException()
    : super._(
        kind: InvoicesErrorKind.noDefaultLiquidWallet,
        code: 'NoDefaultLiquidWallet',
        retryable: false,
      );
}

final class InvoicesInvalidInputException extends InvoicesException {
  const InvoicesInvalidInputException({required super.code})
    : super._(kind: InvoicesErrorKind.invalidInput, retryable: false);
}

final class InvoicesReusedBitcoinAddressException extends InvoicesException {
  const InvoicesReusedBitcoinAddressException()
    : super._(
        kind: InvoicesErrorKind.reusedBitcoinAddress,
        code: 'BitcoinAddressAlreadyUsed',
        retryable: false,
      );
}

final class InvoicesReusedLiquidAddressException extends InvoicesException {
  const InvoicesReusedLiquidAddressException()
    : super._(
        kind: InvoicesErrorKind.reusedLiquidAddress,
        code: 'LiquidAddressAlreadyUsed',
        retryable: false,
      );
}

final class InvoicesNotFoundException extends InvoicesException {
  const InvoicesNotFoundException()
    : super._(
        kind: InvoicesErrorKind.notFound,
        code: 'InvoiceNotFound',
        retryable: false,
      );
}

final class InvoicesAuthException extends InvoicesException {
  const InvoicesAuthException()
    : super._(
        kind: InvoicesErrorKind.authError,
        code: 'AuthError',
        retryable: false,
      );
}

final class InvoicesRateLimitedException extends InvoicesException {
  const InvoicesRateLimitedException()
    : super._(
        kind: InvoicesErrorKind.rateLimited,
        code: 'RateLimited',
        retryable: true,
      );
}

final class InvoicesNetworkException extends InvoicesException {
  const InvoicesNetworkException()
    : super._(
        kind: InvoicesErrorKind.network,
        code: 'NetworkError',
        retryable: true,
      );
}

final class InvoicesTimeoutException extends InvoicesException {
  const InvoicesTimeoutException()
    : super._(
        kind: InvoicesErrorKind.timeout,
        code: 'Timeout',
        retryable: true,
      );
}

final class InvoicesInvalidServerResponseException extends InvoicesException {
  const InvoicesInvalidServerResponseException()
    : super._(
        kind: InvoicesErrorKind.invalidServerResponse,
        code: 'InvalidServerResponse',
        retryable: true,
      );
}

final class InvoicesSigningFailedException extends InvoicesException {
  const InvoicesSigningFailedException()
    : super._(
        kind: InvoicesErrorKind.signingFailed,
        code: 'SigningFailed',
        retryable: false,
      );
}

final class InvoicesServerException extends InvoicesException {
  const InvoicesServerException({required super.retryable})
    : super._(kind: InvoicesErrorKind.server, code: 'ServerError');
}

final class InvoicesUnexpectedException extends InvoicesException {
  const InvoicesUnexpectedException()
    : super._(
        kind: InvoicesErrorKind.unexpected,
        code: 'Unexpected',
        retryable: false,
      );
}
