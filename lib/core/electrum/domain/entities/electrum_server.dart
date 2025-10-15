import 'package:bb_mobile/core/electrum/domain/errors/electrum_server_exception.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';

class ElectrumServer {
  final String _url;
  final ElectrumServerNetwork _network;
  final bool _isCustom;
  // Only the priority can be modified after creation
  int _priority;

  ElectrumServer._({
    required String url,
    required ElectrumServerNetwork network,
    required bool isCustom,
    required int priority,
  }) : _url = url,
       _network = network,
       _isCustom = isCustom,
       _priority = priority;

  // Create a new custom server
  //  (validates URL and adds protocol if missing for Bitcoin network)
  factory ElectrumServer.createCustom({
    required String url,
    required ElectrumServerNetwork network,
    required int priority,
  }) {
    _validateUrl(url, isLiquid: network.isLiquid);
    return ElectrumServer._(
      url: _getUrlWithDefaultProtocol(url, isLiquid: network.isLiquid),
      network: network,
      isCustom: true,
      priority: priority,
    );
  }

  // Rehydrate from existing stored server (assumes data is already validated)
  factory ElectrumServer.existing({
    required String url,
    required ElectrumServerNetwork network,
    required bool isCustom,
    required int priority,
  }) {
    return ElectrumServer._(
      url: url,
      network: network,
      isCustom: isCustom,
      priority: priority,
    );
  }

  String get url => _url;
  ElectrumServerNetwork get network => _network;
  bool get isCustom => _isCustom;
  int get priority => _priority;

  static String _getUrlWithDefaultProtocol(
    String url, {
    required bool isLiquid,
  }) {
    // For Liquid it shouldn't have a protocol, for Bitcoin we default to ssl://
    //  if no protocol is specified
    if (!isLiquid && !url.contains('://')) {
      return 'ssl://$url';
    }
    return url;
  }

  static void _validateUrl(String url, {required bool isLiquid}) {
    if (url.isEmpty) {
      throw InvalidElectrumServerUrlException(url, isLiquid: isLiquid);
    }

    // For Liquid servers, protocol should not be specified
    if (isLiquid && url.contains('://')) {
      throw InvalidElectrumServerUrlException(url, isLiquid: isLiquid);
    }

    // Electrum server URLs can be:
    // 1. host:port (e.g., "example.com:50001")
    // 2. protocol://host:port (e.g., "ssl://example.com:50002", "tcp://example.com:50001")
    // Valid protocols are: tcp, ssl, ws, wss, rpc
    final protocolPattern = RegExp('^(tcp|ssl|ws|wss|rpc)://');
    final urlWithoutProtocol = url.replaceFirst(protocolPattern, '');

    // Check for host:port format
    final hostPortPattern = RegExp(r'^([a-zA-Z0-9\-\.]+):(\d+)$');

    if (!hostPortPattern.hasMatch(urlWithoutProtocol)) {
      throw InvalidElectrumServerUrlException(url, isLiquid: isLiquid);
    }

    // Validate port is in valid range
    final match = hostPortPattern.firstMatch(urlWithoutProtocol);
    if (match != null) {
      final port = int.tryParse(match.group(2)!);
      if (port == null || port < 1 || port > 65535) {
        throw InvalidElectrumServerUrlException(url, isLiquid: isLiquid);
      }
    }
  }

  void updatePriority(int newPriority) {
    if (newPriority < 0) {
      throw InvalidPriorityException(newPriority);
    }

    _priority = newPriority;
  }
}
