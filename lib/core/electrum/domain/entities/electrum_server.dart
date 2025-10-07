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
       _priority = priority;

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
