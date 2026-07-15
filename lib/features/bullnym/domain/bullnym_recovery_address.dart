const int bullnymRecoveryAddressContractVersion = 1;

/// Authenticated read of the merchant-wide automatic-fallback destination.
///
/// The server returns the address only to its signing merchant so a restored
/// wallet can prove ownership and restore its local label. The commitment id,
/// original signature, descriptor, and key material are never exposed.
class BullnymRecoveryAddressLookupResult {
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

  const BullnymRecoveryAddressLookupResult.unregistered()
    : version = bullnymRecoveryAddressContractVersion,
      isRegistered = false,
      btcAddress = null,
      commitmentVersion = null,
      signedAtUnix = null;
}

/// Privacy-safe acknowledgement of an accepted fallback-address commitment.
///
/// The write response deliberately contains no address, npub, signature, or
/// persistence identity. The client verifies [signedAtUnix] against the exact
/// timestamp it signed before accepting this acknowledgement.
class BullnymRecoveryAddressRegistrationResult {
  final int version;
  final bool isRegistered;
  final int signedAtUnix;

  const BullnymRecoveryAddressRegistrationResult({
    required this.version,
    required this.isRegistered,
    required this.signedAtUnix,
  });
}
