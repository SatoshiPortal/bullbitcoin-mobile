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

/// Closed failure family for one-time automatic-fallback setup.
///
/// Remote diagnostic text and all key/address derivation details stop below
/// this boundary. Only a stable code and retryability reach callers.
sealed class AutomaticFallbackFailure extends Failure {
  final AutomaticFallbackFailureKind kind;
  final String code;
  final bool retryable;

  const AutomaticFallbackFailure._({
    required this.kind,
    required this.code,
    required this.retryable,
  });

  const factory AutomaticFallbackFailure.noDefaultBitcoinWallet() =
      _NoDefaultBitcoinWalletFailure;
  const factory AutomaticFallbackFailure.ambiguousDefaultBitcoinWallet() =
      _AmbiguousDefaultBitcoinWalletFailure;
  const factory AutomaticFallbackFailure.walletLookupFailed() =
      _WalletLookupFailedFailure;
  const factory AutomaticFallbackFailure.unsupportedNetwork() =
      _UnsupportedNetworkFailure;
  const factory AutomaticFallbackFailure.signingUnavailable() =
      _SigningUnavailableFailure;
  const factory AutomaticFallbackFailure.addressSelectionFailed() =
      _AddressSelectionFailedFailure;
  const factory AutomaticFallbackFailure.addressVerificationFailed() =
      _AddressVerificationFailedFailure;
  const factory AutomaticFallbackFailure.addressNotOwned() =
      _AddressNotOwnedFailure;
  const factory AutomaticFallbackFailure.conflictingLocalReservations() =
      _ConflictingLocalReservationsFailure;
  const factory AutomaticFallbackFailure.labelPersistenceFailed() =
      _LabelPersistenceFailedFailure;
  const factory AutomaticFallbackFailure.remoteLookupFailed({
    required String code,
    required bool retryable,
  }) = _RemoteLookupFailure;
  const factory AutomaticFallbackFailure.remoteRegistrationFailed({
    required String code,
    required bool retryable,
  }) = _RemoteRegistrationFailure;
  const factory AutomaticFallbackFailure.integrityMismatch() =
      _IntegrityMismatchFailure;
  const factory AutomaticFallbackFailure.unexpected() =
      _AutomaticFallbackUnexpectedFailure;
}

final class _NoDefaultBitcoinWalletFailure extends AutomaticFallbackFailure {
  const _NoDefaultBitcoinWalletFailure()
    : super._(
        kind: AutomaticFallbackFailureKind.noDefaultBitcoinWallet,
        code: 'NoDefaultBitcoinWallet',
        retryable: true,
      );
}

final class _AmbiguousDefaultBitcoinWalletFailure
    extends AutomaticFallbackFailure {
  const _AmbiguousDefaultBitcoinWalletFailure()
    : super._(
        kind: AutomaticFallbackFailureKind.ambiguousDefaultBitcoinWallet,
        code: 'AmbiguousDefaultBitcoinWallet',
        retryable: false,
      );
}

final class _WalletLookupFailedFailure extends AutomaticFallbackFailure {
  const _WalletLookupFailedFailure()
    : super._(
        kind: AutomaticFallbackFailureKind.walletLookupFailed,
        code: 'WalletLookupFailed',
        retryable: true,
      );
}

final class _UnsupportedNetworkFailure extends AutomaticFallbackFailure {
  const _UnsupportedNetworkFailure()
    : super._(
        kind: AutomaticFallbackFailureKind.unsupportedNetwork,
        code: 'UnsupportedNetwork',
        retryable: false,
      );
}

final class _SigningUnavailableFailure extends AutomaticFallbackFailure {
  const _SigningUnavailableFailure()
    : super._(
        kind: AutomaticFallbackFailureKind.signingUnavailable,
        code: 'SigningUnavailable',
        retryable: false,
      );
}

final class _AddressSelectionFailedFailure extends AutomaticFallbackFailure {
  const _AddressSelectionFailedFailure()
    : super._(
        kind: AutomaticFallbackFailureKind.addressSelectionFailed,
        code: 'AddressSelectionFailed',
        retryable: true,
      );
}

final class _AddressVerificationFailedFailure extends AutomaticFallbackFailure {
  const _AddressVerificationFailedFailure()
    : super._(
        kind: AutomaticFallbackFailureKind.addressVerificationFailed,
        code: 'AddressVerificationFailed',
        retryable: true,
      );
}

final class _AddressNotOwnedFailure extends AutomaticFallbackFailure {
  const _AddressNotOwnedFailure()
    : super._(
        kind: AutomaticFallbackFailureKind.addressNotOwned,
        code: 'AddressNotOwned',
        retryable: false,
      );
}

final class _ConflictingLocalReservationsFailure
    extends AutomaticFallbackFailure {
  const _ConflictingLocalReservationsFailure()
    : super._(
        kind: AutomaticFallbackFailureKind.conflictingLocalReservations,
        code: 'ConflictingLocalReservations',
        retryable: false,
      );
}

final class _LabelPersistenceFailedFailure extends AutomaticFallbackFailure {
  const _LabelPersistenceFailedFailure()
    : super._(
        kind: AutomaticFallbackFailureKind.labelPersistenceFailed,
        code: 'LabelPersistenceFailed',
        retryable: true,
      );
}

final class _RemoteLookupFailure extends AutomaticFallbackFailure {
  const _RemoteLookupFailure({required super.code, required super.retryable})
    : super._(kind: AutomaticFallbackFailureKind.remoteLookupFailed);
}

final class _RemoteRegistrationFailure extends AutomaticFallbackFailure {
  const _RemoteRegistrationFailure({
    required super.code,
    required super.retryable,
  }) : super._(kind: AutomaticFallbackFailureKind.remoteRegistrationFailed);
}

final class _IntegrityMismatchFailure extends AutomaticFallbackFailure {
  const _IntegrityMismatchFailure()
    : super._(
        kind: AutomaticFallbackFailureKind.integrityMismatch,
        code: 'IntegrityMismatch',
        retryable: false,
      );
}

final class _AutomaticFallbackUnexpectedFailure
    extends AutomaticFallbackFailure {
  const _AutomaticFallbackUnexpectedFailure()
    : super._(
        kind: AutomaticFallbackFailureKind.unexpected,
        code: 'Unexpected',
        retryable: false,
      );
}
