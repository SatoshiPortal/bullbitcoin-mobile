import 'package:background_tasks/background_tasks.dart';

class GetBackgroundActivityUsecase {
  final BackgroundActivityGateway _gateway;

  const GetBackgroundActivityUsecase({required this._gateway});

  /// Whether the app may run in the background; null where it does not apply.
  Future<bool?> execute() => _gateway.isUnrestricted();
}
