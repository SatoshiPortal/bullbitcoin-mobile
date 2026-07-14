import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

import 'bounded_http.dart';
import 'discovery.dart';
import 'downloader.dart';
import 'failures.dart';
import 'manifest.dart';
import 'model.dart';
import 'release.dart';
import 'release_parser.dart';

/// Raw downloaded bytes, opaque on purpose: the only way to get one is [ColdcardFirmwareClient.download], and the only thing to do with one is pass it to [ColdcardFirmwareClient.verify], which recomputes the hash over its own copy of the bytes. Callers can neither forge one nor mutate its contents into a verified result.
final class DownloadedFirmware {
  DownloadedFirmware._(this.release, this._bytes);

  final FirmwareRelease release;
  final Uint8List _bytes;

  int get sizeBytes => _bytes.length;
}

/// Firmware whose bytes match the SHA-256 in the PGP-verified manifest. Constructed only by [ColdcardFirmwareClient.verify]; [bytes] is an unmodifiable copy taken before hashing, so what was verified is exactly what an export path receives. The app's export path should accept only this type.
final class VerifiedFirmware {
  VerifiedFirmware._({
    required this.release,
    required this.bytes,
    required this.sha256Hex,
    required this.signerFingerprintHex,
  });

  final FirmwareRelease release;

  /// Unmodifiable: writes throw. This is the byte-for-byte content that was hashed and matched against the signed manifest.
  final Uint8List bytes;

  final String sha256Hex;

  /// Fingerprint of the key that signed the manifest (the pinned Coinkite signing key), for display on the "verified" screen.
  final String signerFingerprintHex;
}

/// Orchestrates the firmware flow: discover latest → download → verify.
///
/// Create one per user flow. The verified manifest is fetched once and cached for the client's lifetime so discovery and verification see the same signed data.
///
/// ```dart
/// final client = ColdcardFirmwareClient();
/// final release = await client.fetchLatest(ColdcardModel.q);
/// final downloaded = await client.download(release, onProgress: ...);
/// final verified = await client.verify(downloaded); // throws unless good
/// ```
///
/// The public constructor always uses the production endpoints and the compile-time Coinkite trust anchor; none of them are overridable through the exported API.
final class ColdcardFirmwareClient {
  /// [dio] is optional so the app can supply its own configured instance (interceptors, proxy, later Tor). When omitted, a private instance with connect/receive timeouts is used. Endpoints and the trust anchor are not parameters here by design.
  ColdcardFirmwareClient({Dio? dio})
    : this._withOverrides(dio: dio ?? _defaultDio());

  ColdcardFirmwareClient._withOverrides({
    Dio? dio,
    String baseUrl = ReleasePageScraper.defaultBaseUrl,
    this.manifestUrl = defaultManifestUrl,
    ManifestVerifier? manifestVerifier,
  }) : _dio = dio ?? _defaultDio(),
       _manifestVerifier = manifestVerifier ?? ManifestVerifier() {
    _scraper = ReleasePageScraper(dio: _dio, baseUrl: baseUrl);
    _downloader = FirmwareDownloader(dio: _dio);
  }

  /// signatures.txt in Coinkite's firmware repo. Its PGP signature — not this URL — is what's trusted.
  static const String defaultManifestUrl =
      'https://raw.githubusercontent.com/Coldcard/firmware/master/releases/signatures.txt';

  static Dio _defaultDio() {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        // Time between data events, so a stalled unauthenticated response cannot hang the flow indefinitely.
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 30),
      ),
    );
  }

  final Dio _dio;
  final String manifestUrl;
  final ManifestVerifier _manifestVerifier;
  late final ReleasePageScraper _scraper;
  late final FirmwareDownloader _downloader;

  Future<VerifiedManifest>? _cachedManifest;

  Future<VerifiedManifest> _verifiedManifest() {
    // Cache the future (not the value) so concurrent callers share one fetch; drop it on failure so a retry re-fetches.
    return _cachedManifest ??= _fetchAndVerifyManifest().onError((Object e, _) {
      _cachedManifest = null;
      throw e;
    });
  }

  Future<VerifiedManifest> _fetchAndVerifyManifest() async {
    final text = await getBoundedText(
      _dio,
      manifestUrl,
      maxBytes: maxMetadataResponseBytes,
    );
    return _manifestVerifier.verify(text);
  }

  /// The latest firmware Coinkite currently offers for [model], with the SHA-256 the signed manifest promises for it.
  ///
  /// Scrapes the model's downloads page for the offered release and requires it to appear in the PGP-verified manifest; if the page can't be parsed at all, falls back to the newest manifest entry for the model (the manifest is signed but append-only, so this fallback can name a release Coinkite has since pulled — hence page-first).
  Future<FirmwareRelease> fetchLatest(ColdcardModel model) async {
    final manifest = await _verifiedManifest();

    ParsedFirmwareFilename? parsed;
    try {
      parsed = await _scraper.fetchLatestOffered(model);
    } on DiscoveryParseException {
      parsed = _latestFromManifest(manifest, model);
    }
    if (parsed == null) {
      throw DiscoveryParseException(
        'no ${model.displayName} release found on the downloads page '
        'or in the signed manifest',
      );
    }
    return _releaseFor(manifest, model, parsed);
  }

  ParsedFirmwareFilename? _latestFromManifest(
    VerifiedManifest manifest,
    ColdcardModel model,
  ) {
    final candidates = manifest.sha256ByFilename.keys
        .map(ParsedFirmwareFilename.tryParse)
        .nonNulls
        .where((f) => f.isOfferedFor(model))
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final byVersion = a.version.compareTo(b.version);
      if (byVersion != 0) return byVersion;
      return a.timestampRaw.compareTo(b.timestampRaw);
    });
    return candidates.last;
  }

  FirmwareRelease _releaseFor(
    VerifiedManifest manifest,
    ColdcardModel model,
    ParsedFirmwareFilename parsed,
  ) {
    final expectedSha256 = manifest.sha256ByFilename[parsed.filename];
    if (expectedSha256 == null) {
      throw ReleaseNotInManifestException(parsed.filename);
    }
    return FirmwareRelease(
      model: model,
      version: parsed.version,
      timestampRaw: parsed.timestampRaw,
      filename: parsed.filename,
      downloadUrl: _scraper.downloadUrlFor(parsed.filename),
      expectedSha256Hex: expectedSha256,
    );
  }

  /// Downloads [release]. The result is NOT yet trustworthy — pass it to [verify].
  Future<DownloadedFirmware> download(
    FirmwareRelease release, {
    void Function(int received, int? total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final bytes = await _downloader.download(
      release,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    return DownloadedFirmware._(release, bytes);
  }

  /// Checks [downloaded] against the PGP-verified manifest and returns the verified firmware, or throws.
  ///
  /// The expected hash is looked up in the verified manifest here (never taken from the release object) and the actual hash is recomputed over a private copy of the bytes, so verification stands entirely on its own: neither a lying hash field nor a mutation of shared state can influence it.
  Future<VerifiedFirmware> verify(DownloadedFirmware downloaded) async {
    final manifest = await _verifiedManifest();
    final expected = manifest.sha256ByFilename[downloaded.release.filename];
    if (expected == null) {
      throw ReleaseNotInManifestException(downloaded.release.filename);
    }
    // Copy first, then hash the copy: the copy is what gets exposed, so what was hashed is exactly what the caller receives.
    final bytes = Uint8List.fromList(downloaded._bytes);
    final actual = sha256.convert(bytes).toString();
    if (expected != actual) {
      throw FirmwareHashMismatchException(
        filename: downloaded.release.filename,
        expectedSha256Hex: expected,
        actualSha256Hex: actual,
      );
    }
    return VerifiedFirmware._(
      release: downloaded.release,
      bytes: bytes.asUnmodifiableView(),
      sha256Hex: actual,
      signerFingerprintHex: manifest.signerFingerprintHex,
    );
  }
}

/// Creates a client with test endpoints and a test signing key.
///
/// This is intentionally absent from the package's public barrel.
/// Package-owned tests import this source library explicitly; production callers should use [ColdcardFirmwareClient.new].
@visibleForTesting
ColdcardFirmwareClient createColdcardFirmwareClientForTesting({
  Dio? dio,
  String baseUrl = ReleasePageScraper.defaultBaseUrl,
  String manifestUrl = ColdcardFirmwareClient.defaultManifestUrl,
  ManifestVerifier? manifestVerifier,
}) {
  return ColdcardFirmwareClient._withOverrides(
    dio: dio,
    baseUrl: baseUrl,
    manifestUrl: manifestUrl,
    manifestVerifier: manifestVerifier,
  );
}
