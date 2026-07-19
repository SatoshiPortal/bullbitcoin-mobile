import 'package:bb_mobile/features/get_paid_settings/domain/usecases/get_get_paid_wallet_behaviors_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_registration.dart';

enum LightningAddressActivationStatus {
  loading,
  unsupported,
  idle,
  active,
  activeLocalSetupFailed,
  inactive,
  addressUnavailable,
  submitting,
  failure,
}

enum LightningAddressActivationFailure {
  invalidNym,
  reservedNym,
  nameTaken,
  alreadyAssigned,
  capabilityUnavailable,
  lookupFailed,
  noDefaultBitcoinWallet,
  setupFailed,
  submissionUncertain,
  rejected,
  serverTemporary,
  network,
  toggleUncertain,
  generic,
}

class LightningAddressActivationState {
  final LightningAddressActivationStatus status;
  final LightningAddressActivationFailure? failure;
  final String nym;
  final String? registeredAddress;
  final bool localSetupRetryable;
  final bool permanentNamesSupported;
  final bool hasPermanentNym;
  final LightningAddressPermanentNameQuota? permanentNameQuota;
  final bool onlineSaving;

  /// Whether the receive wallet's persisted autosweep behavior is confirmed
  /// enabled. Only true when a readiness lookup has read the actual metadata
  /// back (R2-D1b); the copy claims autosweep only on this positive signal.
  final bool autoSweepConfirmed;

  /// The reserved Lightning Address wallet's current behavior (auto-sweep /
  /// hide-on-home), resolved read-only. Null until wallet 101 exists.
  final GetPaidWalletBehavior? walletBehavior;

  /// True while a wallet-behavior toggle write is in flight.
  final bool walletBehaviorSaving;

  const LightningAddressActivationState({
    this.status = LightningAddressActivationStatus.loading,
    this.failure,
    this.nym = '',
    this.registeredAddress,
    this.localSetupRetryable = false,
    this.permanentNamesSupported = false,
    this.hasPermanentNym = false,
    this.permanentNameQuota,
    this.onlineSaving = false,
    this.autoSweepConfirmed = false,
    this.walletBehavior,
    this.walletBehaviorSaving = false,
  });

  bool get isLoading => status == LightningAddressActivationStatus.loading;
  bool get isUnsupported =>
      status == LightningAddressActivationStatus.unsupported;
  bool get isSubmitting =>
      status == LightningAddressActivationStatus.submitting;
  bool get isActive => status == LightningAddressActivationStatus.active;
  bool get isActiveLocalSetupFailed =>
      status == LightningAddressActivationStatus.activeLocalSetupFailed;
  bool get isInactive => status == LightningAddressActivationStatus.inactive;
  bool get isAddressUnavailable =>
      status == LightningAddressActivationStatus.addressUnavailable;
  bool get isBusy => isSubmitting || onlineSaving;
  bool get receiveReady => status == LightningAddressActivationStatus.active;

  LightningAddressActivationState copyWith({
    LightningAddressActivationStatus? status,
    LightningAddressActivationFailure? failure,
    String? nym,
    String? registeredAddress,
    bool? localSetupRetryable,
    bool? permanentNamesSupported,
    bool? hasPermanentNym,
    LightningAddressPermanentNameQuota? permanentNameQuota,
    bool? onlineSaving,
    bool? autoSweepConfirmed,
    GetPaidWalletBehavior? walletBehavior,
    bool? walletBehaviorSaving,
    bool clearFailure = false,
    bool clearRegisteredAddress = false,
    bool clearWalletBehavior = false,
    bool clearPermanentNameQuota = false,
  }) {
    return LightningAddressActivationState(
      status: status ?? this.status,
      failure: clearFailure ? null : failure ?? this.failure,
      nym: nym ?? this.nym,
      registeredAddress: clearRegisteredAddress && registeredAddress == null
          ? null
          : registeredAddress ?? this.registeredAddress,
      localSetupRetryable: localSetupRetryable ?? this.localSetupRetryable,
      permanentNamesSupported:
          permanentNamesSupported ?? this.permanentNamesSupported,
      hasPermanentNym: hasPermanentNym ?? this.hasPermanentNym,
      permanentNameQuota: clearPermanentNameQuota
          ? null
          : permanentNameQuota ?? this.permanentNameQuota,
      onlineSaving: onlineSaving ?? this.onlineSaving,
      autoSweepConfirmed: autoSweepConfirmed ?? this.autoSweepConfirmed,
      walletBehavior: clearWalletBehavior
          ? null
          : walletBehavior ?? this.walletBehavior,
      walletBehaviorSaving: walletBehaviorSaving ?? this.walletBehaviorSaving,
    );
  }
}
