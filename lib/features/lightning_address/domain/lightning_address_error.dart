import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/widgets.dart';

enum LightningAddressErrorKind {
  invalidNym,
  reservedNym,
  invalidRegistrationInput,
  localPreparationFailed,
  network,
  timeout,
  serverRejectedRequest,
  invalidServerResponse,
  signingFailed,
  unexpected,
}

enum WalletOwnedLightningAddressRegistrationFailurePhase {
  localPreparation,
  registrationSubmission,
}

enum WalletOwnedLightningAddressActivationFailurePhase {
  localPreparation,
  registrationSubmission,
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

  const factory LightningAddressException.reservedNym() =
      LightningAddressReservedNymException;

  const factory LightningAddressException.invalidRegistrationInput({
    required String code,
    required bool retryable,
  }) = LightningAddressInvalidRegistrationInputException;

  const factory LightningAddressException.localPreparationFailed({
    required String code,
    required bool retryable,
  }) = LightningAddressLocalPreparationFailedException;

  const factory LightningAddressException.unexpected() =
      LightningAddressUnexpectedException;

  String toTranslated(BuildContext context) => switch (kind) {
    LightningAddressErrorKind.invalidNym =>
      context.loc.lightningAddressInvalidNymError,
    LightningAddressErrorKind.reservedNym =>
      context.loc.lightningAddressReservedNymError,
    LightningAddressErrorKind.invalidRegistrationInput =>
      context.loc.lightningAddressInvalidRegistrationInputError,
    LightningAddressErrorKind.localPreparationFailed
        when code == 'NoDefaultBitcoinWallet' =>
      context.loc.lightningAddressNoDefaultBitcoinWalletError,
    LightningAddressErrorKind.localPreparationFailed when retryable =>
      context.loc.lightningAddressLocalPreparationFailedError,
    LightningAddressErrorKind.localPreparationFailed =>
      context.loc.lightningAddressLocalPreparationNotRetryableError,
    LightningAddressErrorKind.network =>
      context.loc.lightningAddressErrorConnectionFailed,
    LightningAddressErrorKind.timeout =>
      context.loc.lightningAddressErrorConnectionFailed,
    LightningAddressErrorKind.serverRejectedRequest when retryable =>
      context.loc.lightningAddressErrorServerUnavailable,
    LightningAddressErrorKind.serverRejectedRequest =>
      context.loc.lightningAddressErrorServerError,
    LightningAddressErrorKind.invalidServerResponse ||
    LightningAddressErrorKind.signingFailed ||
    LightningAddressErrorKind.unexpected =>
      context.loc.lightningAddressErrorUnexpected,
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

final class LightningAddressReservedNymException
    extends LightningAddressException {
  const LightningAddressReservedNymException()
    : super._(
        kind: LightningAddressErrorKind.reservedNym,
        code: 'NymReserved',
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

final class LightningAddressLocalPreparationFailedException
    extends LightningAddressException {
  const LightningAddressLocalPreparationFailedException({
    required super.code,
    required super.retryable,
  }) : super._(kind: LightningAddressErrorKind.localPreparationFailed);
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
  final String? ownedNym;

  const LightningAddressServerRejectedRequestException({
    required super.code,
    required super.retryable,
    this.ownedNym,
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

bool _isLightningAddressRegistrationSubmissionUncertain(
  LightningAddressException error,
) {
  return switch (error.kind) {
    LightningAddressErrorKind.network ||
    LightningAddressErrorKind.timeout ||
    LightningAddressErrorKind.invalidServerResponse => true,
    LightningAddressErrorKind.invalidNym ||
    LightningAddressErrorKind.reservedNym ||
    LightningAddressErrorKind.invalidRegistrationInput ||
    LightningAddressErrorKind.serverRejectedRequest ||
    LightningAddressErrorKind.signingFailed ||
    LightningAddressErrorKind.localPreparationFailed ||
    LightningAddressErrorKind.unexpected => false,
  };
}

bool _canLightningAddressDescriptorHaveReachedServer(
  LightningAddressException error,
) {
  return switch (error.kind) {
    LightningAddressErrorKind.network ||
    LightningAddressErrorKind.timeout ||
    LightningAddressErrorKind.serverRejectedRequest ||
    LightningAddressErrorKind.invalidServerResponse => true,
    LightningAddressErrorKind.invalidNym ||
    LightningAddressErrorKind.reservedNym ||
    LightningAddressErrorKind.invalidRegistrationInput ||
    LightningAddressErrorKind.signingFailed ||
    LightningAddressErrorKind.localPreparationFailed ||
    LightningAddressErrorKind.unexpected => false,
  };
}

final class WalletOwnedLightningAddressRegistrationException
    extends LightningAddressException {
  final WalletOwnedLightningAddressRegistrationFailurePhase phase;
  final LightningAddressException cause;
  final String? walletId;
  final bool walletCreated;
  final bool submissionMayBeUncertain;

  WalletOwnedLightningAddressRegistrationException.localPreparation({
    required this.cause,
  }) : phase =
           WalletOwnedLightningAddressRegistrationFailurePhase.localPreparation,
       walletId = null,
       walletCreated = false,
       submissionMayBeUncertain = false,
       super._(kind: cause.kind, code: cause.code, retryable: cause.retryable);

  WalletOwnedLightningAddressRegistrationException.registrationSubmission({
    required this.cause,
    required this.walletId,
    required this.walletCreated,
  }) : phase = WalletOwnedLightningAddressRegistrationFailurePhase
           .registrationSubmission,
       submissionMayBeUncertain =
           _isLightningAddressRegistrationSubmissionUncertain(cause),
       super._(kind: cause.kind, code: cause.code, retryable: cause.retryable);

  bool get descriptorMayHaveBeenSubmitted =>
      phase ==
          WalletOwnedLightningAddressRegistrationFailurePhase
              .registrationSubmission &&
      _canLightningAddressDescriptorHaveReachedServer(cause);

  @override
  String toTranslated(BuildContext context) => cause.toTranslated(context);

  @override
  String toString() {
    return 'WalletOwnedLightningAddressRegistrationException('
        'phase: $phase, cause: $cause)';
  }
}

final class WalletOwnedLightningAddressActivationException
    extends LightningAddressException {
  final WalletOwnedLightningAddressActivationFailurePhase phase;
  final LightningAddressException cause;
  final bool submissionMayBeUncertain;

  WalletOwnedLightningAddressActivationException.fromRegistration(
    WalletOwnedLightningAddressRegistrationException error,
  ) : phase = switch (error.phase) {
        WalletOwnedLightningAddressRegistrationFailurePhase.localPreparation =>
          WalletOwnedLightningAddressActivationFailurePhase.localPreparation,
        WalletOwnedLightningAddressRegistrationFailurePhase
            .registrationSubmission =>
          WalletOwnedLightningAddressActivationFailurePhase
              .registrationSubmission,
      },
      cause = error.cause,
      submissionMayBeUncertain = error.submissionMayBeUncertain,
      super._(
        kind: error.cause.kind,
        code: error.cause.code,
        retryable: error.cause.retryable,
      );

  @override
  String toTranslated(BuildContext context) => cause.toTranslated(context);

  @override
  String toString() {
    return 'WalletOwnedLightningAddressActivationException('
        'phase: $phase, cause: $cause)';
  }
}
