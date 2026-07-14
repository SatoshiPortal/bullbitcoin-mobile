import 'package:bb_mobile/core/coldcard_firmware/domain/entities/coldcard_device.dart';

/// The latest firmware Coinkite offers for a device, as vouched for by the PGP-verified release manifest.
///
/// Metadata only — holding one of these says nothing about downloaded bytes. Only [VerifiedColdcardFirmwareEntity] represents verified firmware.
final class ColdcardFirmwareReleaseEntity {
  const ColdcardFirmwareReleaseEntity({
    required this.device,
    required this.versionLabel,
    required this.filename,
    required this.sha256Hex,
    this.releasedAt,
  });

  final ColdcardDevice device;

  /// Human-readable version, e.g. `v1.4.1Q` or `v5.5.1`.
  final String versionLabel;

  /// Original release filename (`2026-07-01T1727-v1.4.1Q-q1-coldcard.dfu`). Kept verbatim so the user can cross-check on the device.
  final String filename;

  /// The SHA-256 the signed manifest promises for [filename], for display.
  final String sha256Hex;

  /// Release date parsed from the filename timestamp, when parseable.
  final DateTime? releasedAt;
}
