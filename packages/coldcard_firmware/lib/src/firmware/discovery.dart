import 'package:dio/dio.dart';

import 'bounded_http.dart';
import 'failures.dart';
import 'model.dart';
import 'release_parser.dart';

/// Finds the firmware releases currently offered on a model's coldcard.com downloads page.
///
/// The page is plain HTML with `href="/downloads/<filename>.dfu"` links (there is no machine-readable index). Scraped results are only ever a *candidate list* — nothing is shown to the user until the chosen file is also found in the PGP-verified manifest.
final class ReleasePageScraper {
  ReleasePageScraper({required this.dio, this.baseUrl = defaultBaseUrl});

  static const String defaultBaseUrl = 'https://coldcard.com';

  final Dio dio;
  final String baseUrl;

  static final RegExp _dfuHref = RegExp(
    r'href="/downloads/([^"/]+\.dfu)"',
    caseSensitive: false,
  );

  /// Extracts parseable firmware filenames from downloads-page HTML. Unparseable hrefs are skipped (they are not offered files).
  static List<ParsedFirmwareFilename> extractOffered(String html) {
    return _dfuHref
        .allMatches(html)
        .map((m) => ParsedFirmwareFilename.tryParse(m.group(1)!))
        .nonNulls
        .toList();
  }

  String downloadUrlFor(String filename) => '$baseUrl/downloads/$filename';

  /// Fetches [model]'s downloads page and returns the latest offered (non-edge, non-factory) release filename for it.
  Future<ParsedFirmwareFilename> fetchLatestOffered(ColdcardModel model) async {
    final url = '$baseUrl/downloads/${model.downloadsPagePath}';
    final html = await getBoundedText(
      dio,
      url,
      maxBytes: maxMetadataResponseBytes,
    );

    final offered = extractOffered(
      html,
    ).where((f) => f.isOfferedFor(model)).toList();
    if (offered.isEmpty) {
      throw DiscoveryParseException(
        'no ${model.displayName} firmware found on $url '
        '(page layout may have changed)',
      );
    }

    offered.sort((a, b) {
      final byVersion = a.version.compareTo(b.version);
      if (byVersion != 0) return byVersion;
      // Same version re-published: the filename timestamp breaks the tie.
      return a.timestampRaw.compareTo(b.timestampRaw);
    });
    return offered.last;
  }
}
