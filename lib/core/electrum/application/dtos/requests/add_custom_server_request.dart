import 'package:bb_mobile/core/electrum/application/dtos/electrum_server_dto.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';

class AddCustomServerRequest {
  final ElectrumServerDto server;

  AddCustomServerRequest({required this.server});

  String get host => server.url.split(':').first;
  int get port => int.parse(server.url.split(':').last);
  ElectrumServerNetwork get network => server.network;
  bool get isCustom => server.isCustom;
  int get priority => server.priority;
  bool get enableSsl => server.enableSsl;
}
