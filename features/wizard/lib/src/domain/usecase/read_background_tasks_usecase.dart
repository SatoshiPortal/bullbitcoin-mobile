import 'package:background_tasks/background_tasks.dart';

/// Whether background tasks are on, from the interval stored before the app
/// is initialized. `null` when it cannot be read.
class ReadBackgroundTasksUsecase {
  ReadBackgroundTasksUsecase({required this._intervals});

  final BackgroundSyncIntervalRepository _intervals;

  Future<bool?> execute() async {
    try {
      return (await _intervals.read()).isEnabled;
    } on Exception {
      return null;
    }
  }
}
