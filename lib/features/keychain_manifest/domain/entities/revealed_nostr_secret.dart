final class RevealedNostrSecret {
  final String nsec;

  const RevealedNostrSecret._(this.nsec);

  factory RevealedNostrSecret(String nsec) {
    if (!nsec.startsWith('nsec1')) throw ArgumentError('Invalid nsec');
    return RevealedNostrSecret._(nsec);
  }

  @override
  String toString() => 'RevealedNostrSecret([REDACTED])';
}
