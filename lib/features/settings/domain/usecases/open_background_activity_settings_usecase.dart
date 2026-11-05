import 'package:background_tasks/background_tasks.dart';

class OpenBackgroundActivitySettingsUsecase {
  final BackgroundActivityGateway _gateway;

  const OpenBackgroundActivitySettingsUsecase({required this._gateway});

  Future<bool> execute() => _gateway.openSettings();
}
