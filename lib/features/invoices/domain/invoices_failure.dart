import 'package:bb_mobile/core/failures/failure.dart';

enum InvoicesFailureKind {
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
  privateStorage,
  encryption,
  outcomeUnknown,
  createConflict,
  signingFailed,
  server,
  unexpected,
}

/// Closed family of recoverable invoice failures. Raw exceptions are mapped
/// at the Invoices data boundary and never cross into presentation or UI.
sealed class InvoicesFailure extends Failure {
  final InvoicesFailureKind kind;
  final String code;
  final bool retryable;

  const InvoicesFailure._({
    required this.kind,
    required this.code,
    required this.retryable,
    String? logMessage,
  }) : super(logMessage);

  const factory InvoicesFailure.noDefaultBitcoinWallet() =
      InvoicesNoDefaultBitcoinWalletFailure;

  const factory InvoicesFailure.noDefaultLiquidWallet() =
      InvoicesNoDefaultLiquidWalletFailure;

  const factory InvoicesFailure.invalidInput({
    required String code,
    String? logMessage,
  }) = InvoicesInvalidInputFailure;

  const factory InvoicesFailure.reusedBitcoinAddress() =
      InvoicesReusedBitcoinAddressFailure;

  const factory InvoicesFailure.reusedLiquidAddress() =
      InvoicesReusedLiquidAddressFailure;

  const factory InvoicesFailure.notFound() = InvoicesNotFoundFailure;

  const factory InvoicesFailure.authError() = InvoicesAuthFailure;

  const factory InvoicesFailure.rateLimited() = InvoicesRateLimitedFailure;

  const factory InvoicesFailure.network() = InvoicesNetworkFailure;

  const factory InvoicesFailure.timeout() = InvoicesTimeoutFailure;

  const factory InvoicesFailure.invalidServerResponse() =
      InvoicesInvalidServerResponseFailure;

  const factory InvoicesFailure.privateStorage() =
      InvoicesPrivateStorageFailure;

  const factory InvoicesFailure.encryption() = InvoicesEncryptionFailure;

  const factory InvoicesFailure.outcomeUnknown() =
      InvoicesOutcomeUnknownFailure;

  const factory InvoicesFailure.createConflict() =
      InvoicesCreateConflictFailure;

  const factory InvoicesFailure.signingFailed() = InvoicesSigningFailedFailure;

  const factory InvoicesFailure.server({required bool retryable}) =
      InvoicesServerFailure;

  const factory InvoicesFailure.unexpected([String? logMessage]) =
      InvoicesUnexpectedFailure;

  @override
  String toString() => 'InvoicesFailure($code)';
}

final class InvoicesNoDefaultBitcoinWalletFailure extends InvoicesFailure {
  const InvoicesNoDefaultBitcoinWalletFailure()
    : super._(
        kind: InvoicesFailureKind.noDefaultBitcoinWallet,
        code: 'NoDefaultBitcoinWallet',
        retryable: false,
      );
}

final class InvoicesNoDefaultLiquidWalletFailure extends InvoicesFailure {
  const InvoicesNoDefaultLiquidWalletFailure()
    : super._(
        kind: InvoicesFailureKind.noDefaultLiquidWallet,
        code: 'NoDefaultLiquidWallet',
        retryable: false,
      );
}

final class InvoicesInvalidInputFailure extends InvoicesFailure {
  const InvoicesInvalidInputFailure({required super.code, super.logMessage})
    : super._(kind: InvoicesFailureKind.invalidInput, retryable: false);
}

final class InvoicesReusedBitcoinAddressFailure extends InvoicesFailure {
  const InvoicesReusedBitcoinAddressFailure()
    : super._(
        kind: InvoicesFailureKind.reusedBitcoinAddress,
        code: 'BitcoinAddressAlreadyUsed',
        retryable: false,
      );
}

final class InvoicesReusedLiquidAddressFailure extends InvoicesFailure {
  const InvoicesReusedLiquidAddressFailure()
    : super._(
        kind: InvoicesFailureKind.reusedLiquidAddress,
        code: 'LiquidAddressAlreadyUsed',
        retryable: false,
      );
}

final class InvoicesNotFoundFailure extends InvoicesFailure {
  const InvoicesNotFoundFailure()
    : super._(
        kind: InvoicesFailureKind.notFound,
        code: 'InvoiceNotFound',
        retryable: false,
      );
}

final class InvoicesAuthFailure extends InvoicesFailure {
  const InvoicesAuthFailure()
    : super._(
        kind: InvoicesFailureKind.authError,
        code: 'AuthError',
        retryable: false,
      );
}

final class InvoicesRateLimitedFailure extends InvoicesFailure {
  const InvoicesRateLimitedFailure()
    : super._(
        kind: InvoicesFailureKind.rateLimited,
        code: 'RateLimited',
        retryable: true,
      );
}

final class InvoicesNetworkFailure extends InvoicesFailure {
  const InvoicesNetworkFailure()
    : super._(
        kind: InvoicesFailureKind.network,
        code: 'NetworkError',
        retryable: true,
      );
}

final class InvoicesTimeoutFailure extends InvoicesFailure {
  const InvoicesTimeoutFailure()
    : super._(
        kind: InvoicesFailureKind.timeout,
        code: 'Timeout',
        retryable: true,
      );
}

final class InvoicesInvalidServerResponseFailure extends InvoicesFailure {
  const InvoicesInvalidServerResponseFailure()
    : super._(
        kind: InvoicesFailureKind.invalidServerResponse,
        code: 'InvalidServerResponse',
        retryable: true,
      );
}

final class InvoicesPrivateStorageFailure extends InvoicesFailure {
  const InvoicesPrivateStorageFailure()
    : super._(
        kind: InvoicesFailureKind.privateStorage,
        code: 'PrivateInvoiceStorageUnavailable',
        retryable: true,
      );
}

final class InvoicesEncryptionFailure extends InvoicesFailure {
  const InvoicesEncryptionFailure()
    : super._(
        kind: InvoicesFailureKind.encryption,
        code: 'PrivateInvoiceEncryptionUnavailable',
        retryable: true,
      );
}

final class InvoicesOutcomeUnknownFailure extends InvoicesFailure {
  const InvoicesOutcomeUnknownFailure()
    : super._(
        kind: InvoicesFailureKind.outcomeUnknown,
        code: 'InvoiceCreateOutcomeUnknown',
        retryable: true,
      );
}

final class InvoicesCreateConflictFailure extends InvoicesFailure {
  const InvoicesCreateConflictFailure()
    : super._(
        kind: InvoicesFailureKind.createConflict,
        code: 'InvoiceCreateConflict',
        retryable: false,
      );
}

final class InvoicesSigningFailedFailure extends InvoicesFailure {
  const InvoicesSigningFailedFailure()
    : super._(
        kind: InvoicesFailureKind.signingFailed,
        code: 'SigningFailed',
        retryable: false,
      );
}

final class InvoicesServerFailure extends InvoicesFailure {
  const InvoicesServerFailure({required super.retryable})
    : super._(kind: InvoicesFailureKind.server, code: 'ServerError');
}

final class InvoicesUnexpectedFailure extends InvoicesFailure {
  const InvoicesUnexpectedFailure([String? logMessage])
    : super._(
        kind: InvoicesFailureKind.unexpected,
        code: 'Unexpected',
        retryable: false,
        logMessage: logMessage,
      );
}
