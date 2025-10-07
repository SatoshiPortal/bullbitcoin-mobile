import 'package:bb_mobile/core/electrum/domain/errors/electrum_server_error.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';

class ElectrumServer {
  final String _url;
  final ElectrumServerNetwork _network;
  final bool _isCustom;
  // Only the priority can be modified after creation
  int _priority;

  ElectrumServer({
    required String url,
    required ElectrumServerNetwork network,
    required bool isCustom,
    required int priority,
  }) : _url = url,
       _network = network,
       _isCustom = isCustom,
       _priority = priority {
    _validateUrl(url);
  }

  static void _validateUrl(String url) {
    if (url.isEmpty) {
      throw InvalidElectrumServerUrlError(url);
    }

    // Electrum server URLs can be:
    // 1. host:port (e.g., "example.com:50001")
    // 2. protocol://host:port (e.g., "ssl://example.com:50002", "tcp://example.com:50001")

    final protocolPattern = RegExp(r'^(ssl|tcp|wss)://');
    final urlWithoutProtocol = url.replaceFirst(protocolPattern, '');

    // Check for host:port format
    final hostPortPattern = RegExp(r'^([a-zA-Z0-9\-\.]+):(\d+)$');

    if (!hostPortPattern.hasMatch(urlWithoutProtocol)) {
      throw InvalidElectrumServerUrlError(url);
    }

    // Validate port is in valid range
    final match = hostPortPattern.firstMatch(urlWithoutProtocol);
    if (match != null) {
      final port = int.tryParse(match.group(2)!);
      if (port == null || port < 1 || port > 65535) {
        throw InvalidElectrumServerUrlError(url);
      }
    }
  }

  String get url => _url;
  ElectrumServerNetwork get network => _network;
  bool get isCustom => _isCustom;
  int get priority => _priority;

  void updatePriority(int newPriority) {
    if (newPriority < 0) {
      throw InvalidPriorityError(newPriority);
    }

    _priority = newPriority;
  }
}
