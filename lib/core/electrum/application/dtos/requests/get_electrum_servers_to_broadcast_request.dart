import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';

class GetElectrumServersToBroadcastRequest {
  final ElectrumServerNetwork network;

  GetElectrumServersToBroadcastRequest({required this.network});
}
