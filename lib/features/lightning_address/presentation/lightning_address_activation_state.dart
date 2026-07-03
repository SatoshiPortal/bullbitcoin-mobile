enum LightningAddressActivationStatus {
  loading,
  idle,
  active,
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
  network,
  generic,
}

class LightningAddressActivationState {
  final LightningAddressActivationStatus status;
  final LightningAddressActivationFailure? failure;
  final String nym;
  final String? registeredAddress;

  const LightningAddressActivationState({
    this.status = LightningAddressActivationStatus.loading,
    this.failure,
    this.nym = '',
    this.registeredAddress,
  });

  bool get isLoading => status == LightningAddressActivationStatus.loading;
  bool get isSubmitting =>
      status == LightningAddressActivationStatus.submitting;
  bool get isRegistered =>
      status == LightningAddressActivationStatus.registered;
  bool get isActive => status == LightningAddressActivationStatus.active;
  bool get isInactive => status == LightningAddressActivationStatus.inactive;

  LightningAddressActivationState copyWith({
    LightningAddressActivationStatus? status,
    LightningAddressActivationFailure? failure,
    String? nym,
    String? registeredAddress,
    bool clearFailure = false,
    bool clearRegisteredAddress = false,
  }) {
    return LightningAddressActivationState(
      status: status ?? this.status,
      failure: clearFailure ? null : failure ?? this.failure,
      nym: nym ?? this.nym,
      registeredAddress: clearRegisteredAddress
          ? null
          : registeredAddress ?? this.registeredAddress,
    );
  }
}
