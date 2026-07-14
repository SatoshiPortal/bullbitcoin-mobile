import 'dart:typed_data';

import 'package:bb_mobile/core/coldcard_firmware/domain/entities/coldcard_firmware_release_entity.dart';

/// Firmware whose bytes were downloaded and verified against Coinkite's PGP-signed release manifest (signature by the pinned signing key, plus SHA-256 match). This is the only type the export flow accepts.
final class VerifiedColdcardFirmwareEntity {
  const VerifiedColdcardFirmwareEntity({
    required this.release,
    required this.bytes,
    required this.sha256Hex,
    required this.signerName,
    required this.signerFingerprintHex,
  });

  final ColdcardFirmwareReleaseEntity release;

  /// Verified content, unmodifiable. Write this to the microSD as [release.filename].
  final Uint8List bytes;

  final String sha256Hex;

  /// Human-readable identity of the manifest signer, for display.
  final String signerName;

  final String signerFingerprintHex;
}
