import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';

class AddCustomServerRequest {
  final String url;
  final ElectrumServerNetwork network;
  final bool isCustom;
  final int priority;

  AddCustomServerRequest({
    required this.url,
    required this.network,
    required this.isCustom,
    required this.priority,
  });
}
