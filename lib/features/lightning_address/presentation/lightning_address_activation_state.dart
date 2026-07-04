enum LightningAddressActivationStatus {
  loading,
  idle,
  active,
  activeLocalSetupFailed,
  inactive,
  submitting,
  registered,
  failure,
}

enum LightningAddressActivationFailure {
  invalidNym,
  lookupFailed,
  noDefaultBitcoinWallet,
  setupFailed,
  submissionUncertain,
  rejected,
  serverTemporary,
  network,
  generic,
}

class LightningAddressActivationState {
  final LightningAddressActivationStatus status;
  final LightningAddressActivationFailure? failure;
  final String nym;
  final String? registeredAddress;
  final bool localSetupRetryable;

  /// Whether the receive wallet's persisted autosweep behavior is confirmed
  /// enabled. Only true when a readiness lookup has read the actual metadata
  /// back (R2-D1b); the copy claims autosweep only on this positive signal.
  final bool autoSweepConfirmed;

  const LightningAddressActivationState({
    this.status = LightningAddressActivationStatus.loading,
    this.failure,
    this.nym = '',
    this.registeredAddress,
    this.localSetupRetryable = false,
    this.autoSweepConfirmed = false,
  });

  bool get isLoading => status == LightningAddressActivationStatus.loading;
  bool get isSubmitting =>
      status == LightningAddressActivationStatus.submitting;
  bool get isRegistered =>
      status == LightningAddressActivationStatus.registered;
  bool get isActive => status == LightningAddressActivationStatus.active;
  bool get isActiveLocalSetupFailed =>
      status == LightningAddressActivationStatus.activeLocalSetupFailed;
  bool get isInactive => status == LightningAddressActivationStatus.inactive;
  bool get receiveReady =>
      status == LightningAddressActivationStatus.active ||
      status == LightningAddressActivationStatus.registered;

  LightningAddressActivationState copyWith({
    LightningAddressActivationStatus? status,
    LightningAddressActivationFailure? failure,
    String? nym,
    String? registeredAddress,
    bool? localSetupRetryable,
    bool? autoSweepConfirmed,
    bool clearFailure = false,
    bool clearRegisteredAddress = false,
  }) {
    return LightningAddressActivationState(
      status: status ?? this.status,
      failure: clearFailure ? null : failure ?? this.failure,
      nym: nym ?? this.nym,
      registeredAddress: clearRegisteredAddress && registeredAddress == null
          ? null
          : registeredAddress ?? this.registeredAddress,
      localSetupRetryable: localSetupRetryable ?? this.localSetupRetryable,
      autoSweepConfirmed: autoSweepConfirmed ?? this.autoSweepConfirmed,
    );
  }
}
