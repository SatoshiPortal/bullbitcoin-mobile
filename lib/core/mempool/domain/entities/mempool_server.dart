import 'package:bb_mobile/core/mempool/domain/errors/mempool_server_exception.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';

class MempoolServer {
  final String _url;
  final MempoolServerNetwork _network;
  final bool _isCustom;

  MempoolServer._({
    required String url,
    required MempoolServerNetwork network,
    required bool isCustom,
  }) : _url = url,
       _network = network,
       _isCustom = isCustom;

  factory MempoolServer.createCustom({
    required String url,
    required MempoolServerNetwork network,
  }) {
    final cleanedUrl = _validateAndCleanUrl(url);
    return MempoolServer._(url: cleanedUrl, network: network, isCustom: true);
  }

  factory MempoolServer.existing({
    required String url,
    required MempoolServerNetwork network,
    required bool isCustom,
  }) {
    return MempoolServer._(url: url, network: network, isCustom: isCustom);
  }

  static String _validateAndCleanUrl(String url) {
    if (url.isEmpty) {
      throw InvalidMempoolUrlException('URL cannot be empty');
    }

    // Remove protocol if present
    String cleanedUrl = url.replaceFirst(RegExp(r'^https?://'), '');

    // Remove trailing slash
    cleanedUrl = cleanedUrl.replaceFirst(RegExp(r'/$'), '');

    if (cleanedUrl.isEmpty) {
      throw InvalidMempoolUrlException('Invalid URL format');
    }

    // Basic domain validation - should contain at least one dot or be localhost
    if (!cleanedUrl.contains('.') && !cleanedUrl.startsWith('localhost')) {
      throw InvalidMempoolUrlException(
        'Invalid URL format: must be a valid domain',
      );
    }

    return cleanedUrl;
  }

  String get url => _url;
  MempoolServerNetwork get network => _network;
  bool get isCustom => _isCustom;
  String get fullUrl => 'https://$_url';

  bool get isTestnet => _network.isTestnet;
  bool get isLiquid => _network.isLiquid;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MempoolServer &&
          runtimeType == other.runtimeType &&
          _url == other._url &&
          _network == other._network &&
          _isCustom == other._isCustom;

  @override
  int get hashCode => _url.hashCode ^ _network.hashCode ^ _isCustom.hashCode;

  @override
  String toString() =>
      'MempoolServer(url: $_url, network: $_network, isCustom: $_isCustom)';
}
