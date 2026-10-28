import 'package:shared_preferences/shared_preferences.dart';

/// How often the user asks the system to check for incoming payments. The
/// system may delay or skip a check; [off] cancels background checks.
enum BackgroundSyncInterval {
  minutes15(Duration(minutes: 15)),
  minutes30(Duration(minutes: 30)),
  hour1(Duration(hours: 1)),
  hours6(Duration(hours: 6)),
  hours24(Duration(hours: 24)),
  off(null);

  final Duration? frequency;

  const BackgroundSyncInterval(this.frequency);

  static const fallback = hour1;
}

abstract interface class BackgroundSyncIntervalStore {
  Future<BackgroundSyncInterval> read();
  Future<void> write(BackgroundSyncInterval interval);
}

/// Shared preferences, readable before the app database is opened and from
/// the background engine.
final class SharedPreferencesBackgroundSyncIntervalStore
    implements BackgroundSyncIntervalStore {
  static const _key = 'background_sync_interval';

  const SharedPreferencesBackgroundSyncIntervalStore();

  @override
  Future<BackgroundSyncInterval> read() async {
    final name = (await SharedPreferences.getInstance()).getString(_key);
    return BackgroundSyncInterval.values.firstWhere(
      (interval) => interval.name == name,
      orElse: () => BackgroundSyncInterval.fallback,
    );
  }

  @override
  Future<void> write(BackgroundSyncInterval interval) async {
    final saved = await (await SharedPreferences.getInstance()).setString(
      _key,
      interval.name,
    );
    if (!saved) throw StateError('background sync interval not saved');
  }
}
