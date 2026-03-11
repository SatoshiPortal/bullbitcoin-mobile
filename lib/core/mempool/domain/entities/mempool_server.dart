import 'package:bb_mobile/core/mempool/domain/errors/mempool_server_exception.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/utils/mempool_url_parser.dart';

class MempoolServer {
  final String _url;
  final MempoolServerNetwork _network;
  final bool _isCustom;
  final bool _enableSsl;

  MempoolServer._({
    required String url,
    required MempoolServerNetwork network,
    required bool isCustom,
    required bool enableSsl,
  }) : _url = url,
       _network = network,
       _isCustom = isCustom,
       _enableSsl = enableSsl;

  factory MempoolServer.createCustom({
    required String url,
    required MempoolServerNetwork network,
    bool enableSsl = true,
  }) {
    final cleanedUrl = _validateAndCleanUrl(url);
    return MempoolServer._(
      url: cleanedUrl,
      network: network,
      isCustom: true,
      enableSsl: enableSsl,
    );
  }

  factory MempoolServer.existing({
    required String url,
    required MempoolServerNetwork network,
    required bool isCustom,
    bool enableSsl = true,
  }) {
    return MempoolServer._(
      url: url,
      network: network,
      isCustom: isCustom,
      enableSsl: enableSsl,
    );
  }

  static String _validateAndCleanUrl(String url) {
    try {
      final result = MempoolUrlParser.parse(url);
      return result.cleanUrl;
    } on MempoolUrlValidationError catch (e) {
      switch (e) {
        case MempoolUrlValidationError.empty:
          throw InvalidMempoolUrlException('URL cannot be empty');
        case MempoolUrlValidationError.hasPath:
          throw InvalidMempoolUrlException(
            'URL should not contain paths. Enter only the domain or IP address',
          );
        case MempoolUrlValidationError.invalidDomain:
          throw InvalidMempoolUrlException(
            'Invalid URL format: must be a valid domain',
          );
        case MempoolUrlValidationError.invalidFormat:
          throw InvalidMempoolUrlException('Invalid URL format');
      }
    }
  }

  String get url => _url;
  MempoolServerNetwork get network => _network;
  bool get isCustom => _isCustom;
  bool get enableSsl => _enableSsl;
  String get fullUrl => _enableSsl ? 'https://$_url' : 'http://$_url';

  bool get isTestnet => _network.isTestnet;
  bool get isLiquid => _network.isLiquid;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MempoolServer &&
          runtimeType == other.runtimeType &&
          _url == other._url &&
          _network == other._network &&
          _isCustom == other._isCustom &&
          _enableSsl == other._enableSsl;

  @override
  int get hashCode =>
      _url.hashCode ^
      _network.hashCode ^
      _isCustom.hashCode ^
      _enableSsl.hashCode;

  @override
  String toString() =>
      'MempoolServer(url: $_url, network: $_network, isCustom: $_isCustom, enableSsl: $_enableSsl)';
}
