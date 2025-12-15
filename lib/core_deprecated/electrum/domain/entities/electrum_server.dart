import 'package:bb_mobile/core_deprecated/electrum/domain/errors/electrum_server_exception.dart';
import 'package:bb_mobile/core_deprecated/electrum/domain/value_objects/electrum_server_network.dart';

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
  //  (validates URL and adds protocol based on enableSsl for Bitcoin network)
  factory ElectrumServer.createCustom({
    required String host,
    required int port,
    required ElectrumServerNetwork network,
    required int priority,
    bool enableSsl = true,
  }) {
    if (port < 1 || port > 65535) {
      throw InvalidPortException(port);
    }
    return ElectrumServer._(
      url: _getUrlWithProtocol(
        host,
        port,
        enableSsl,
        isLiquid: network.isLiquid,
      ),
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

  static String _getUrlWithProtocol(
    String host,
    int port,
    bool enableSsl, {
    required bool isLiquid,
  }) {
    // Extract any existing protocol from the input
    final urlWithoutProtocol = '$host:$port';
    if (isLiquid) {
      // For Liquid, always use ssl://
      // TODO: This should return `'ssl://$urlWithoutProtocol';`, but lwk expects
      // Liquid URLs without protocol prefix, so we strip it here for now. We
      // should do the stripping in the layer where the library is used instead
      // though.
      return urlWithoutProtocol;
    }

    // For Bitcoin, use enableSsl toggle to decide between ssl:// and tcp://
    return enableSsl
        ? 'ssl://$urlWithoutProtocol'
        : 'tcp://$urlWithoutProtocol';
  }

  void updatePriority(int newPriority) {
    if (newPriority < 0) {
      throw InvalidPriorityException(newPriority);
    }

    _priority = newPriority;
  }
}
