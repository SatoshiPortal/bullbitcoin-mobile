/// Typed failures for the firmware download/verify pipeline.
///
/// Every failure is a distinct type so callers can map them to user-facing messages and so nothing can be confused with a success path: any of these thrown means no green checkmark and no export.
library;

sealed class ColdcardFirmwareException implements Exception {
  const ColdcardFirmwareException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// A network request failed (DNS, TLS, timeout, non-2xx status...).
final class FirmwareNetworkException extends ColdcardFirmwareException {
  const FirmwareNetworkException(this.url, String message)
    : super('$url: $message');

  final String url;
}

/// The downloads page could not be parsed into any firmware release for the requested model (page redesign, unexpected content, empty page).
final class DiscoveryParseException extends ColdcardFirmwareException {
  const DiscoveryParseException(super.message);
}

/// The release filename is absent from the verified manifest, so nothing signed by Coinkite vouches for it.
final class ReleaseNotInManifestException extends ColdcardFirmwareException {
  const ReleaseNotInManifestException(this.filename)
    : super('$filename is not listed in the verified signatures.txt');

  final String filename;
}

/// The manifest is not a well-formed clear-signed message, or its signature did not verify.
final class ManifestSignatureException extends ColdcardFirmwareException {
  const ManifestSignatureException(super.message);
}

/// A signature verified, but not by the pinned Coinkite signing key — treated exactly like an invalid signature, but reported distinctly because it indicates key substitution rather than corruption.
final class ManifestWrongKeyException extends ColdcardFirmwareException {
  const ManifestWrongKeyException({
    required this.expectedFingerprintHex,
    required this.actualFingerprintHex,
  }) : super(
         'manifest signed by $actualFingerprintHex, '
         'expected $expectedFingerprintHex',
       );

  final String expectedFingerprintHex;
  final String actualFingerprintHex;
}

/// The downloaded bytes hash to something other than the manifest entry.
final class FirmwareHashMismatchException extends ColdcardFirmwareException {
  const FirmwareHashMismatchException({
    required this.filename,
    required this.expectedSha256Hex,
    required this.actualSha256Hex,
  }) : super(
         '$filename: expected sha256 $expectedSha256Hex, '
         'got $actualSha256Hex',
       );

  final String filename;
  final String expectedSha256Hex;
  final String actualSha256Hex;
}

/// The download exceeded the sanity size cap (real firmware is ~1-2 MB).
final class FirmwareTooLargeException extends ColdcardFirmwareException {
  const FirmwareTooLargeException(this.limitBytes)
    : super('download exceeded $limitBytes bytes');

  final int limitBytes;
}

/// A metadata response (downloads page or manifest) exceeded its size cap. These are small text documents; an oversized response is refused before it can exhaust memory.
final class ResponseTooLargeException extends ColdcardFirmwareException {
  const ResponseTooLargeException(this.url, this.limitBytes)
    : super('$url: response exceeded $limitBytes bytes');

  final String url;
  final int limitBytes;
}
