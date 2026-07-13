import 'package:dart_pg/dart_pg.dart';
import 'package:meta/meta.dart';

import 'failures.dart';
import 'trusted_key.dart';

/// The release manifest (signatures.txt) after its PGP signature has been checked against the pinned Coinkite signing key.
final class VerifiedManifest {
  VerifiedManifest({
    required Map<String, String> sha256ByFilename,
    required this.signerFingerprintHex,
  }) : sha256ByFilename = Map<String, String>.unmodifiable(sha256ByFilename);

  /// Every `<sha256>  <filename>` entry of the signed body, filename → lowercase hex digest. Unmodifiable.
  final Map<String, String> sha256ByFilename;

  final String signerFingerprintHex;
}

/// Verifies the clear-signed manifest against the bundled trust anchor.
///
/// The production constructor takes no parameters: the key and its fingerprint come from trusted_key.dart at compile time and cannot be swapped through the exported API (this class is not in the package barrel; the client only accepts one via a test-only constructor).
final class ManifestVerifier {
  /// Production verifier, pinned to the compile-time Coinkite trust anchor.
  ManifestVerifier()
    : trustedKeyArmored = trustedSignerKeyArmored,
      expectedFingerprintHex = trustedSignerFingerprintHex;

  /// Test-only: verify against a different anchor so this package's tests can exercise wrong-key and end-to-end paths with a throwaway key. The analyzer rejects use outside this package's tests.
  @visibleForTesting
  ManifestVerifier.withTrustAnchor({
    required this.trustedKeyArmored,
    required String expectedFingerprintHex,
  }) : expectedFingerprintHex = expectedFingerprintHex.toLowerCase();

  final String trustedKeyArmored;
  final String expectedFingerprintHex;

  static final RegExp _entryPattern = RegExp(r'^([0-9a-f]{64})\s{2}(\S+)$');

  /// Verifies [clearsignedText] and returns its signed entries.
  ///
  /// Throws [ManifestWrongKeyException] if the bundled key does not match the pinned fingerprint (a tampered build), [ManifestSignatureException] if the text is malformed or its signature does not verify against the pinned key.
  VerifiedManifest verify(String clearsignedText) {
    final bool verifiedByTrustedKey;
    final String trustedFingerprint;
    final String signedBody;
    try {
      final trustedKey = OpenPGP.readPublicKey(trustedKeyArmored);
      trustedFingerprint = _hex(trustedKey.fingerprint);
      if (trustedFingerprint != expectedFingerprintHex) {
        // The compiled-in key does not match the compiled-in fingerprint: never verify anything with it.
        throw ManifestWrongKeyException(
          expectedFingerprintHex: expectedFingerprintHex,
          actualFingerprintHex: trustedFingerprint,
        );
      }
      final signedMessage = SignedMessage.fromArmored(clearsignedText);
      final trustedKeyId = _hex(trustedKey.keyID);
      verifiedByTrustedKey = signedMessage
          .verify([trustedKey])
          .any((v) => v.isVerified && _hex(v.keyID) == trustedKeyId);
      signedBody = signedMessage.text;
    } on ColdcardFirmwareException {
      rethrow;
    } on Exception catch (e) {
      throw ManifestSignatureException('manifest verification failed: $e');
    } on AssertionError catch (e) {
      // Not a programmer error here: dart_pg signals armor integrity and armor type failures of the UNTRUSTED input with AssertionError (see its Armor.decode), so for this boundary it means "not a valid clear-signed manifest".
      throw ManifestSignatureException('malformed manifest armor: $e');
    } on RangeError catch (e) {
      // Truncated armor payloads surface as out-of-range reads inside dart_pg's packet parsing; same reasoning as above.
      throw ManifestSignatureException('truncated manifest: $e');
    }
    if (!verifiedByTrustedKey) {
      throw const ManifestSignatureException(
        'no valid signature by the pinned Coinkite signing key',
      );
    }

    final entries = <String, String>{};
    for (final line in signedBody.split('\n')) {
      final match = _entryPattern.firstMatch(line.trimRight());
      if (match != null) {
        entries[match.group(2)!] = match.group(1)!;
      }
    }
    if (entries.isEmpty) {
      throw const ManifestSignatureException(
        'verified manifest contains no hash entries',
      );
    }

    return VerifiedManifest(
      sha256ByFilename: entries,
      signerFingerprintHex: trustedFingerprint,
    );
  }

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
