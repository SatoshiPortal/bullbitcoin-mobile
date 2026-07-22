import 'dart:io';

import 'package:coldcard_firmware/coldcard_firmware.dart';
import 'package:coldcard_firmware/src/firmware/client.dart'
    show createColdcardFirmwareClientForTesting;
import 'package:coldcard_firmware/src/firmware/manifest.dart'
    show ManifestVerifier;
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

import 'manifest_test.dart' show testKeyFingerprintHex;

/// End-to-end flow against a local server, using the throwaway test key as trust anchor (fixtures: test_key_public.asc signs test_manifest_clearsigned.txt which lists fake_firmware.dfu).
void main() {
  final testManifest = File(
    'test/fixtures/test_manifest_clearsigned.txt',
  ).readAsStringSync();
  final testKeyArmored = File(
    'test/fixtures/test_key_public.asc',
  ).readAsStringSync();
  final fakeFirmware = File(
    'test/fixtures/fake_firmware.dfu',
  ).readAsBytesSync();
  const fakeMkFilename = '2026-01-01T0000-v9.9.9-mk-coldcard.dfu';
  const fakeQFilename = '2026-01-01T0000-v9.9.9Q-q1-coldcard.dfu';

  late HttpServer server;
  late String baseUrl;
  late Map<String, Object> routes; // String (text) or List<int> (bytes)

  setUp(() async {
    routes = {};
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://127.0.0.1:${server.port}';
    server.listen((request) {
      final body = routes[request.uri.path];
      switch (body) {
        case null:
          request.response.statusCode = HttpStatus.notFound;
        case final String text:
          request.response.write(text);
        case final List<int> bytes:
          request.response.contentLength = bytes.length;
          request.response.add(bytes);
        default:
          request.response.statusCode = HttpStatus.internalServerError;
      }
      request.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  ColdcardFirmwareClient buildClient() {
    return createColdcardFirmwareClientForTesting(
      dio: Dio(),
      baseUrl: baseUrl,
      manifestUrl: '$baseUrl/manifest/signatures.txt',
      manifestVerifier: ManifestVerifier.withTrustAnchor(
        trustedKeyArmored: testKeyArmored,
        expectedFingerprintHex: testKeyFingerprintHex,
      ),
    );
  }

  test('happy path: fetchLatest → download → verify', () async {
    routes['/manifest/signatures.txt'] = testManifest;
    routes['/downloads/mk'] =
        '<a href="/downloads/$fakeMkFilename">$fakeMkFilename</a>';
    routes['/downloads/$fakeMkFilename'] = fakeFirmware;

    final client = buildClient();
    final release = await client.fetchLatest(ColdcardModel.mk4);
    expect(release.filename, fakeMkFilename);
    expect(release.version, const FirmwareVersion(9, 9, 9));
    expect(release.expectedSha256Hex, hasLength(64));

    final progress = <int>[];
    final downloaded = await client.download(
      release,
      onProgress: (received, _) => progress.add(received),
    );
    expect(progress.last, fakeFirmware.length);
    expect(downloaded.sizeBytes, fakeFirmware.length);

    final verified = await client.verify(downloaded);
    expect(verified.bytes, fakeFirmware);
    expect(verified.sha256Hex, release.expectedSha256Hex);
    expect(verified.sha256Hex, sha256.convert(fakeFirmware).toString());
    expect(verified.signerFingerprintHex, testKeyFingerprintHex);
    expect(verified.release.filename, fakeMkFilename);
  });

  test('happy path for the Q model', () async {
    routes['/manifest/signatures.txt'] = testManifest;
    routes['/downloads/q1'] =
        '<a href="/downloads/$fakeQFilename">$fakeQFilename</a>';
    routes['/downloads/$fakeQFilename'] = fakeFirmware;

    final client = buildClient();
    final release = await client.fetchLatest(ColdcardModel.q);
    expect(release.filename, fakeQFilename);
    final verified = await client.verify(await client.download(release));
    expect(verified.release.model, ColdcardModel.q);
  });

  test('VerifiedFirmware.bytes is an unmodifiable copy', () async {
    routes['/manifest/signatures.txt'] = testManifest;
    routes['/downloads/mk'] =
        '<a href="/downloads/$fakeMkFilename">$fakeMkFilename</a>';
    routes['/downloads/$fakeMkFilename'] = fakeFirmware;

    final client = buildClient();
    final release = await client.fetchLatest(ColdcardModel.mk4);
    final verified = await client.verify(await client.download(release));

    expect(() => verified.bytes[0] = 0xFF, throwsUnsupportedError);
    expect(() => verified.bytes.setAll(0, [1, 2, 3]), throwsUnsupportedError);
    expect(verified.bytes, fakeFirmware);
  });

  test('tampered firmware bytes fail verification with HashMismatch', () async {
    routes['/manifest/signatures.txt'] = testManifest;
    routes['/downloads/mk'] =
        '<a href="/downloads/$fakeMkFilename">$fakeMkFilename</a>';
    final tampered = List<int>.from(fakeFirmware);
    tampered[100] ^= 0xFF;
    routes['/downloads/$fakeMkFilename'] = tampered;

    final client = buildClient();
    final release = await client.fetchLatest(ColdcardModel.mk4);
    final downloaded = await client.download(release);
    expect(
      () => client.verify(downloaded),
      throwsA(isA<FirmwareHashMismatchException>()),
    );
  });

  test('verify recomputes the hash: a forged release hash cannot rescue bad '
      'bytes', () async {
    // The release object's expectedSha256Hex is caller-visible state. Serve bytes matching NOTHING in the manifest and confirm verify fails even though fetchLatest populated a "correct" expected hash for the filename.
    routes['/manifest/signatures.txt'] = testManifest;
    routes['/downloads/mk'] =
        '<a href="/downloads/$fakeMkFilename">$fakeMkFilename</a>';
    routes['/downloads/$fakeMkFilename'] = List<int>.filled(4096, 0x42);

    final client = buildClient();
    final release = await client.fetchLatest(ColdcardModel.mk4);
    expect(
      release.expectedSha256Hex,
      sha256.convert(fakeFirmware).toString(),
    ); // manifest's claim
    final downloaded = await client.download(release);
    expect(
      () => client.verify(downloaded),
      throwsA(isA<FirmwareHashMismatchException>()),
    );
  });

  test('a release offered on the page but absent from the manifest is '
      'rejected at discovery', () async {
    routes['/manifest/signatures.txt'] = testManifest;
    const unlisted = '2026-02-02T0000-v9.9.8-mk-coldcard.dfu';
    routes['/downloads/mk'] = '<a href="/downloads/$unlisted">x</a>';

    final client = buildClient();
    expect(
      () => client.fetchLatest(ColdcardModel.mk4),
      throwsA(isA<ReleaseNotInManifestException>()),
    );
  });

  test('a manifest not signed by the pinned key fails everything', () async {
    // Serve the REAL Coinkite manifest but pin the test key.
    routes['/manifest/signatures.txt'] = File(
      'test/fixtures/signatures.txt',
    ).readAsStringSync();
    routes['/downloads/mk'] =
        '<a href="/downloads/$fakeMkFilename">$fakeMkFilename</a>';

    final client = buildClient();
    expect(
      () => client.fetchLatest(ColdcardModel.mk4),
      throwsA(isA<ManifestSignatureException>()),
    );
  });

  test('an oversized manifest response is refused', () async {
    routes['/manifest/signatures.txt'] = 'A' * (5 * 1024 * 1024);
    routes['/downloads/mk'] =
        '<a href="/downloads/$fakeMkFilename">$fakeMkFilename</a>';

    final client = buildClient();
    expect(
      () => client.fetchLatest(ColdcardModel.mk4),
      throwsA(isA<ResponseTooLargeException>()),
    );
  });

  test('an oversized downloads page is refused', () async {
    routes['/manifest/signatures.txt'] = testManifest;
    routes['/downloads/mk'] = 'B' * (5 * 1024 * 1024);

    final client = buildClient();
    expect(
      () => client.fetchLatest(ColdcardModel.mk4),
      throwsA(isA<ResponseTooLargeException>()),
    );
  });

  test(
    'falls back to the manifest when the page has no parseable releases',
    () async {
      routes['/manifest/signatures.txt'] = testManifest;
      routes['/downloads/mk'] = '<html>page redesign, no dfu links</html>';
      routes['/downloads/$fakeMkFilename'] = fakeFirmware;

      final client = buildClient();
      final release = await client.fetchLatest(ColdcardModel.mk4);
      expect(release.filename, fakeMkFilename);
      final verified = await client.verify(await client.download(release));
      expect(verified.sha256Hex, release.expectedSha256Hex);
    },
  );

  test('manifest fetch failure surfaces as FirmwareNetworkException and a '
      'retry can succeed', () async {
    routes['/downloads/mk'] =
        '<a href="/downloads/$fakeMkFilename">$fakeMkFilename</a>';
    final client = buildClient();
    await expectLater(
      () => client.fetchLatest(ColdcardModel.mk4), // manifest 404s
      throwsA(isA<FirmwareNetworkException>()),
    );

    routes['/manifest/signatures.txt'] = testManifest; // "outage" over
    final release = await client.fetchLatest(ColdcardModel.mk4);
    expect(release.filename, fakeMkFilename);
  });
}
