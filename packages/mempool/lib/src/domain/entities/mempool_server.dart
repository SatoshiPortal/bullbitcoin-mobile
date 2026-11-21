import 'package:mempool/src/domain/mempool_failure.dart';
import 'package:mempool/src/domain/services/mempool_url_parser.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class MempoolServer {
  final String _url;
  final Network _network;
  final bool _isCustom;
  final bool _enableSsl;

  MempoolServer._({
    required this._url,
    required this._network,
    required this._isCustom,
    required this._enableSsl,
  });

  /// Validates [url] and builds a custom server, returning a typed failure
  /// (never throwing) when the URL is malformed.
  @useResult
  static Result<MempoolServer, MempoolFailure> tryCreateCustom({
    required String url,
    required Network network,
    bool enableSsl = true,
  }) {
    if (!NetworkCapabilities.supports(
      network,
      NetworkCapability.publicExplorer,
    )) {
      return Err(MempoolUnsupportedNetworkFailure(network));
    }
    final parsed = MempoolUrlParser.tryParse(url);
    if (parsed == null) {
      return const Err(MempoolInvalidUrlFailure());
    }
    return Ok(
      MempoolServer._(
        url: parsed.cleanUrl,
        network: network,
        isCustom: true,
        enableSsl: enableSsl,
      ),
    );
  }

  @internal
  factory MempoolServer.existing({
    required String url,
    required Network network,
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

  String get url => _url;
  Network get network => _network;
  bool get isCustom => _isCustom;
  bool get enableSsl => _enableSsl;
  bool get canUseForFeeEstimation => _enableSsl;
  String get fullUrl => _enableSsl ? 'https://$_url' : 'http://$_url';

  /// Suggests the TLS setting encoded by a valid custom server URL.
  static bool? suggestedSsl(String input) =>
      MempoolUrlParser.tryParse(input)?.enableSsl;

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
