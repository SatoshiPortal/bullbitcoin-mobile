/// Historical BIP85 record. The stored path and enum text are lossless.
final class RecordedDerivation {
  final String path;
  final String parentFingerprint;
  final String application;
  final String status;
  final String? alias;

  static final _hardenedPath = RegExp(
    r"^(?:m/)?(?:[0-9]+['hH]/)+([0-9]+)['hH]$",
  );

  const RecordedDerivation({
    required this.path,
    required this.parentFingerprint,
    required this.application,
    required this.status,
    required this.alias,
  });

  /// A hardened child index, independent of how the path spells hardening.
  int? get index {
    final index = _hardenedPath.firstMatch(path)?.group(1);
    if (index == null) return null;
    final value = int.tryParse(index);
    return value == null || value >= 0x80000000 ? null : value;
  }
}
