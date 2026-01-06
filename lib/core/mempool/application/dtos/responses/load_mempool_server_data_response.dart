import 'package:bb_mobile/core/mempool/application/dtos/mempool_server_dto.dart';
import 'package:bb_mobile/core/mempool/application/dtos/mempool_settings_dto.dart';

class LoadMempoolServerDataResponse {
  final MempoolServerDto defaultServer;
  final MempoolServerDto? customServer;
  final MempoolSettingsDto settings;

  LoadMempoolServerDataResponse({
    required this.defaultServer,
    this.customServer,
    required this.settings,
  });

  bool get hasCustomServer => customServer != null;

  @override
  String toString() =>
      'LoadMempoolServerDataResponse(defaultServer: $defaultServer, customServer: $customServer, settings: $settings)';
}
