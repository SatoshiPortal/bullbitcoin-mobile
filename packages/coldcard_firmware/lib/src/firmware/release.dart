import 'model.dart';

/// Semantic version of a firmware release, compared only within one model's version space (Q's v1.x and Mk4's v5.x are unrelated sequences).
final class FirmwareVersion implements Comparable<FirmwareVersion> {
  const FirmwareVersion(
    this.major,
    this.minor,
    this.patch, {
    this.hasQMarker = false,
  });

  final int major;
  final int minor;
  final int patch;

  /// True for Q-model builds (`v1.4.1Q`).
  final bool hasQMarker;

  @override
  int compareTo(FirmwareVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  @override
  bool operator ==(Object other) =>
      other is FirmwareVersion &&
      other.major == major &&
      other.minor == minor &&
      other.patch == patch &&
      other.hasQMarker == hasQMarker;

  @override
  int get hashCode => Object.hash(major, minor, patch, hasQMarker);

  @override
  String toString() => 'v$major.$minor.$patch${hasQMarker ? 'Q' : ''}';
}

/// A firmware release offered for download: already matched to a model, never an edge (`X`) or `-factory` build, and carrying the SHA-256 the verified manifest promises for it.
///
/// This is untrusted metadata. Verification never reads [expectedSha256Hex] — the hash is re-looked-up in the verified manifest by [filename] and recomputed over the actual bytes, so a forged release can at worst fail verification, never pass it.
final class FirmwareRelease {
  const FirmwareRelease({
    required this.model,
    required this.version,
    required this.timestampRaw,
    required this.filename,
    required this.downloadUrl,
    required this.expectedSha256Hex,
  });

  final ColdcardModel model;
  final FirmwareVersion version;

  /// Release timestamp as encoded in the filename (`2026-07-01T1729`).
  final String timestampRaw;

  /// Original release filename; keep it when saving so the user can cross-check on the device.
  final String filename;

  final String downloadUrl;

  /// SHA-256 (lowercase hex) for [filename] from the PGP-verified signatures.txt, for display. This is a claim, not a verdict — only a `VerifiedFirmware` represents a completed check.
  final String expectedSha256Hex;

  @override
  String toString() => '$filename (${model.displayName} $version)';
}
