final class AutomaticFallbackSetup {
  final String btcAddress;
  final int commitmentVersion;
  final int signedAtUnix;
  final bool registeredNow;

  AutomaticFallbackSetup({
    required this.btcAddress,
    required this.commitmentVersion,
    required this.signedAtUnix,
    required this.registeredNow,
  }) {
    if (btcAddress.isEmpty) {
      throw ArgumentError.value(btcAddress, 'btcAddress', 'must not be empty');
    }
    if (commitmentVersion <= 0) {
      throw ArgumentError.value(
        commitmentVersion,
        'commitmentVersion',
        'must be positive',
      );
    }
    if (signedAtUnix < 0) {
      throw ArgumentError.value(
        signedAtUnix,
        'signedAtUnix',
        'must not be negative',
      );
    }
  }
}
