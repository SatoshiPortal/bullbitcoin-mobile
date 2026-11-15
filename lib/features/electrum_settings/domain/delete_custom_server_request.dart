import 'package:bb_mobile/features/electrum_settings/domain/electrum_server_network.dart';

class DeleteCustomServerRequest {
  final String url;
  final ElectrumServerNetwork network;

  DeleteCustomServerRequest({required this.url, required this.network});
}
