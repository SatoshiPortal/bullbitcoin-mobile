import 'package:background_tasks/background_tasks.dart';

class OpenBatterySettingsUsecase {
  OpenBatterySettingsUsecase({required this._gateway});

  final BackgroundActivityGateway _gateway;

  Future<bool> execute() => _gateway.openSettings();
}
