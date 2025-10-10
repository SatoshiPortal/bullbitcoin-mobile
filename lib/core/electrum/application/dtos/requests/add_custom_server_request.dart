import 'package:bb_mobile/core/electrum/application/dtos/electrum_server_dto.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';

class AddCustomServerRequest {
  final ElectrumServerDto server;

  AddCustomServerRequest({required this.server});

  String get url => server.url;
  ElectrumServerNetwork get network => server.network;
  bool get isCustom => server.isCustom;
  int get priority => server.priority;
}
