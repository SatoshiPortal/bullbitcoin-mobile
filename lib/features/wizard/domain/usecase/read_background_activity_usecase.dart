import 'package:background_tasks/background_tasks.dart';

class ReadBackgroundActivityUsecase {
  ReadBackgroundActivityUsecase({required this._gateway});

  final BackgroundActivityGateway _gateway;

  /// Whether the app may run in the background; null where it does not apply.
  Future<bool?> execute() => _gateway.isUnrestricted();
}
