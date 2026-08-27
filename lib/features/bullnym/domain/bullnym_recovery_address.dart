const bullnymRecoveryAddressContractVersion = 1;

final class BullnymRecoveryAddressLookupResult {
  final int version;
  final bool isRegistered;
  final String? btcAddress;
  final int? commitmentVersion;
  final int? signedAtUnix;

  const BullnymRecoveryAddressLookupResult({
    required this.version,
    required this.isRegistered,
    this.btcAddress,
    this.commitmentVersion,
    this.signedAtUnix,
  });
}

final class BullnymRecoveryAddressRegistrationResult {
  final int version;
  final bool isRegistered;
  final int signedAtUnix;

  const BullnymRecoveryAddressRegistrationResult({
    required this.version,
    required this.isRegistered,
    required this.signedAtUnix,
  });
}
