import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';

class GetElectrumServersToUseRequest {
  final ElectrumServerNetwork network;

  GetElectrumServersToUseRequest({required this.network});
}
