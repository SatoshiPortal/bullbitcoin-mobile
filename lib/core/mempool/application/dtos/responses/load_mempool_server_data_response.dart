import 'package:bb_mobile/core/mempool/application/dtos/mempool_server_dto.dart';

class LoadMempoolServerDataResponse {
  final MempoolServerDto defaultServer;
  final MempoolServerDto? customServer;

  LoadMempoolServerDataResponse({
    required this.defaultServer,
    this.customServer,
  });

  bool get hasCustomServer => customServer != null;

  @override
  String toString() =>
      'LoadMempoolServerDataResponse(defaultServer: $defaultServer, customServer: $customServer)';
}
