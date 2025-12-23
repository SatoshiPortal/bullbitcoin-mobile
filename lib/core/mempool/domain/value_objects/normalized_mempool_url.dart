/// Value object for normalized Mempool URL
/// 
/// Handles URL normalization (lowercase, no protocol, no trailing slash)
/// and provides equality comparison for URL matching
class NormalizedMempoolUrl {
  final String _normalized;

  NormalizedMempoolUrl(String url) : _normalized = _normalize(url);

  /// create from an already normalized URL (e.g., from database)
  NormalizedMempoolUrl.fromNormalized(this._normalized);

  static String _normalize(String url) {
    if (url.isEmpty) return '';
    
    return url
        .replaceFirst(RegExp(r'^https?://'), '')
        .replaceFirst(RegExp(r'/$'), '')
        .toLowerCase()
        .trim();
  }

  String get value => _normalized;

  String get fullUrl => 'https://$_normalized';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NormalizedMempoolUrl && _normalized == other._normalized;

  @override
  int get hashCode => _normalized.hashCode;

  @override
  String toString() => 'NormalizedMempoolUrl($_normalized)';
}
