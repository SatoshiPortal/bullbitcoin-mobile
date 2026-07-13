import 'dart:io';

import 'package:coldcard_firmware/coldcard_firmware.dart';
import 'package:coldcard_firmware/src/firmware/manifest.dart'
    show ManifestVerifier;
import 'package:test/test.dart';

/// Fingerprint of the throwaway key that signed test_manifest_clearsigned.txt
/// (see test/fixtures/README.md).
const testKeyFingerprintHex = 'd63d334e08f1530dcbf87402915e31d6cca4e552';

void main() {
  final realManifest = File('test/fixtures/signatures.txt').readAsStringSync();
  final testManifest = File(
    'test/fixtures/test_manifest_clearsigned.txt',
  ).readAsStringSync();
  final testKeyArmored = File(
    'test/fixtures/test_key_public.asc',
  ).readAsStringSync();

  group('ManifestVerifier with the bundled Coinkite key', () {
    test('verifies the real signatures.txt and extracts entries', () {
      final manifest = ManifestVerifier().verify(realManifest);
      expect(manifest.signerFingerprintHex, trustedSignerFingerprintHex);
      expect(
        manifest.sha256ByFilename['2026-07-01T1729-v5.5.1-mk-coldcard.dfu'],
        'f752eade8c7f1d02524549606f429b61f1d792a832fa76f92e735306699fc697',
      );
      expect(
        manifest.sha256ByFilename['2026-07-01T1727-v1.4.1Q-q1-coldcard.dfu'],
        isNotNull,
      );
      expect(manifest.sha256ByFilename.length, greaterThan(100));
    });

    test('rejects a manifest with one flipped hash character', () {
      final tampered = realManifest.replaceFirst(
        'f752eade8c7f1d02524549606f429b61f1d792a832fa76f92e735306699fc697',
        'f752eade8c7f1d02524549606f429b61f1d792a832fa76f92e735306699fc698',
      );
      expect(
        tampered,
        isNot(realManifest),
        reason: 'fixture must contain the known v5.5.1 hash',
      );
      expect(
        () => ManifestVerifier().verify(tampered),
        throwsA(isA<ManifestSignatureException>()),
      );
    });

    test('rejects a manifest with an appended entry', () {
      final injected = realManifest.replaceFirst(
        '-----BEGIN PGP SIGNATURE-----',
        '${'0' * 64}  2099-01-01T0000-v9.9.9-mk-coldcard.dfu\n'
            '-----BEGIN PGP SIGNATURE-----',
      );
      expect(
        () => ManifestVerifier().verify(injected),
        throwsA(isA<ManifestSignatureException>()),
      );
    });

    test('rejects a manifest signed by a different key', () {
      // testManifest is well-formed and validly signed — just not by
      // Coinkite's key.
      expect(
        () => ManifestVerifier().verify(testManifest),
        throwsA(isA<ManifestSignatureException>()),
      );
    });

    test('rejects garbage and truncated input', () {
      expect(
        () => ManifestVerifier().verify('not a manifest'),
        throwsA(isA<ManifestSignatureException>()),
      );
      expect(
        () => ManifestVerifier().verify(
          realManifest.substring(0, realManifest.length ~/ 2),
        ),
        throwsA(isA<ManifestSignatureException>()),
      );
    });
  });

  group('ManifestVerifier key pinning', () {
    test('a bundled key that does not match the pin is never used', () {
      final verifier = ManifestVerifier.withTrustAnchor(
        trustedKeyArmored: testKeyArmored,
        // pin says Coinkite, bundle is the test key -> tampered build
        expectedFingerprintHex: trustedSignerFingerprintHex,
      );
      expect(
        () => verifier.verify(testManifest),
        throwsA(isA<ManifestWrongKeyException>()),
      );
    });

    test('with the test key pinned, the test manifest verifies', () {
      final verifier = ManifestVerifier.withTrustAnchor(
        trustedKeyArmored: testKeyArmored,
        expectedFingerprintHex: testKeyFingerprintHex,
      );
      final manifest = verifier.verify(testManifest);
      expect(manifest.signerFingerprintHex, testKeyFingerprintHex);
      expect(
        manifest.sha256ByFilename['2026-01-01T0000-v9.9.9-mk-coldcard.dfu'],
        isNotNull,
      );
      expect(manifest.sha256ByFilename, hasLength(2));
    });

    test('with the test key pinned, the REAL manifest no longer verifies', () {
      final verifier = ManifestVerifier.withTrustAnchor(
        trustedKeyArmored: testKeyArmored,
        expectedFingerprintHex: testKeyFingerprintHex,
      );
      expect(
        () => verifier.verify(realManifest),
        throwsA(isA<ManifestSignatureException>()),
      );
    });
  });

  test('the verified entry map is unmodifiable', () {
    final manifest = ManifestVerifier().verify(realManifest);
    expect(
      () => manifest.sha256ByFilename['evil.dfu'] = '00',
      throwsUnsupportedError,
    );
  });

  test('bundled trust anchor matches its documented fingerprint', () {
    // Belt and braces for reviewers: the constant in trusted_key.dart is
    // self-consistent (the armored key really has the pinned fingerprint).
    final manifest = ManifestVerifier().verify(realManifest);
    expect(
      manifest.signerFingerprintHex,
      '4589779adfc14f3327534ea8a3a31bad5a2a5b10',
    );
  });
}
