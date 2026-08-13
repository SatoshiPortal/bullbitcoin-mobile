import 'package:bb_mobile/core/mempool/domain/errors/mempool_failure.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/utils/mempool_url_parser.dart';
import 'package:bb_mobile/core/utils/result.dart';

class MempoolServer {
  final String _url;
  final MempoolServerNetwork _network;
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
  static Result<MempoolServer, MempoolFailure> tryCreateCustom({
    required String url,
    required MempoolServerNetwork network,
    bool enableSsl = true,
  }) {
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

  String get url => _url;
  MempoolServerNetwork get network => _network;
  bool get isCustom => _isCustom;
  bool get enableSsl => _enableSsl;
  bool get canUseForFeeEstimation => _enableSsl;
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
