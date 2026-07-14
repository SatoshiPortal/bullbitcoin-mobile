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

  static final RegExp _timestampPattern = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2})(\d{2})$',
  );

  /// Release timestamp parsed from the timezone-less wall-clock components encoded in the filename, represented as UTC to avoid local daylight-saving normalization, or null when [timestampRaw] is malformed.
  DateTime? get releasedAt {
    final match = _timestampPattern.firstMatch(timestampRaw);
    if (match == null) return null;

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final hour = int.parse(match.group(4)!);
    final minute = int.parse(match.group(5)!);

    // UTC preserves the filename's wall-clock components even when the same local time would fall inside a daylight-saving gap; it does not assert that upstream published the release in UTC.
    final releasedAt = DateTime.utc(year, month, day, hour, minute);
    if (releasedAt.year != year ||
        releasedAt.month != month ||
        releasedAt.day != day ||
        releasedAt.hour != hour ||
        releasedAt.minute != minute) {
      return null;
    }
    return releasedAt;
  }

  @override
  String toString() => '$filename (${model.displayName} $version)';
}
