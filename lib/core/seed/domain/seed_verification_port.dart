abstract interface class SeedVerificationPort {
  Future<bool> matchesXpubs({
    required String fingerprint,
    required List<({String derivationPath, String xpub})> keys,
  });
}
