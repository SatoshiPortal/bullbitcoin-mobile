import 'package:bb_mobile/core/utils/mempool_url_parser.dart';

/// Value object for normalized Mempool URL
///
/// Handles URL normalization (lowercase, no protocol, no trailing slash)
/// and provides equality comparison for URL matching
class NormalizedMempoolUrl {
  final String _normalized;
  final bool _enableSsl;

  NormalizedMempoolUrl(String url, {this._enableSsl = true})
    : _normalized = url.isEmpty ? '' : _normalize(url);

  static String _normalize(String url) {
    return MempoolUrlParser.tryParse(url)?.cleanUrl ??
        url.trim().toLowerCase().replaceFirst(RegExp(r'\.$'), '');
  }

  /// create from an already normalized URL (e.g., from database)
  NormalizedMempoolUrl.fromNormalized(
    this._normalized, {
    this._enableSsl = true,
  });

  String get value => _normalized;
  bool get enableSsl => _enableSsl;

  String get fullUrl =>
      _enableSsl ? 'https://$_normalized' : 'http://$_normalized';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NormalizedMempoolUrl &&
          _normalized == other._normalized &&
          _enableSsl == other._enableSsl;

  @override
  int get hashCode => _normalized.hashCode ^ _enableSsl.hashCode;

  @override
  String toString() =>
      'NormalizedMempoolUrl($_normalized, enableSsl: $_enableSsl)';
}
