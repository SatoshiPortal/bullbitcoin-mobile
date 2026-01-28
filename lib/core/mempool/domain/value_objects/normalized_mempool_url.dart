import 'package:bb_mobile/core/utils/mempool_url_parser.dart';

/// Value object for normalized Mempool URL
///
/// Handles URL normalization (lowercase, no protocol, no trailing slash)
/// and provides equality comparison for URL matching
class NormalizedMempoolUrl {
  final String _normalized;
  final bool _enableSsl;

  NormalizedMempoolUrl(String url, {bool enableSsl = true})
      : _normalized = url.isEmpty ? '' : MempoolUrlParser.normalizeUrl(url),
        _enableSsl = enableSsl;

  /// create from an already normalized URL (e.g., from database)
  NormalizedMempoolUrl.fromNormalized(this._normalized, {bool enableSsl = true})
      : _enableSsl = enableSsl;

  String get value => _normalized;
  bool get enableSsl => _enableSsl;

  String get fullUrl => _enableSsl ? 'https://$_normalized' : 'http://$_normalized';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NormalizedMempoolUrl &&
          _normalized == other._normalized &&
          _enableSsl == other._enableSsl;

  @override
  int get hashCode => _normalized.hashCode ^ _enableSsl.hashCode;

  @override
  String toString() => 'NormalizedMempoolUrl($_normalized, enableSsl: $_enableSsl)';
}
