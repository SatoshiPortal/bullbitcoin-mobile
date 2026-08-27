import 'package:bb_mobile/core/failures/failure.dart';

enum AutomaticFallbackFailureKind {
  noDefaultBitcoinWallet,
  ambiguousDefaultBitcoinWallet,
  walletLookupFailed,
  unsupportedNetwork,
  signingUnavailable,
  addressSelectionFailed,
  addressVerificationFailed,
  addressNotOwned,
  conflictingLocalReservations,
  labelPersistenceFailed,
  remoteLookupFailed,
  remoteRegistrationFailed,
  integrityMismatch,
  unexpected,
}

final class AutomaticFallbackFailure extends Failure {
  final AutomaticFallbackFailureKind kind;
  final String code;
  final bool retryable;

  const AutomaticFallbackFailure._(this.kind, this.code, this.retryable);

  const AutomaticFallbackFailure.noDefaultBitcoinWallet()
    : this._(
        AutomaticFallbackFailureKind.noDefaultBitcoinWallet,
        'NoDefaultBitcoinWallet',
        true,
      );

  const AutomaticFallbackFailure.ambiguousDefaultBitcoinWallet()
    : this._(
        AutomaticFallbackFailureKind.ambiguousDefaultBitcoinWallet,
        'AmbiguousDefaultBitcoinWallet',
        false,
      );

  const AutomaticFallbackFailure.walletLookupFailed()
    : this._(
        AutomaticFallbackFailureKind.walletLookupFailed,
        'WalletLookupFailed',
        true,
      );

  const AutomaticFallbackFailure.unsupportedNetwork()
    : this._(
        AutomaticFallbackFailureKind.unsupportedNetwork,
        'UnsupportedNetwork',
        false,
      );

  const AutomaticFallbackFailure.signingUnavailable()
    : this._(
        AutomaticFallbackFailureKind.signingUnavailable,
        'SigningUnavailable',
        false,
      );

  const AutomaticFallbackFailure.addressSelectionFailed()
    : this._(
        AutomaticFallbackFailureKind.addressSelectionFailed,
        'AddressSelectionFailed',
        true,
      );

  const AutomaticFallbackFailure.addressVerificationFailed()
    : this._(
        AutomaticFallbackFailureKind.addressVerificationFailed,
        'AddressVerificationFailed',
        true,
      );

  const AutomaticFallbackFailure.addressNotOwned()
    : this._(
        AutomaticFallbackFailureKind.addressNotOwned,
        'AddressNotOwned',
        false,
      );

  const AutomaticFallbackFailure.conflictingLocalReservations()
    : this._(
        AutomaticFallbackFailureKind.conflictingLocalReservations,
        'ConflictingLocalReservations',
        false,
      );

  const AutomaticFallbackFailure.labelPersistenceFailed()
    : this._(
        AutomaticFallbackFailureKind.labelPersistenceFailed,
        'LabelPersistenceFailed',
        true,
      );

  const AutomaticFallbackFailure.remoteLookupFailed({
    required String code,
    required bool retryable,
  }) : this._(AutomaticFallbackFailureKind.remoteLookupFailed, code, retryable);

  const AutomaticFallbackFailure.remoteRegistrationFailed({
    required String code,
    required bool retryable,
  }) : this._(
         AutomaticFallbackFailureKind.remoteRegistrationFailed,
         code,
         retryable,
       );

  const AutomaticFallbackFailure.integrityMismatch()
    : this._(
        AutomaticFallbackFailureKind.integrityMismatch,
        'IntegrityMismatch',
        false,
      );

  const AutomaticFallbackFailure.unexpected()
    : this._(AutomaticFallbackFailureKind.unexpected, 'Unexpected', false);
}
