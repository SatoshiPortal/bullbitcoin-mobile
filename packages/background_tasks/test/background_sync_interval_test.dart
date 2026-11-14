import 'package:background_tasks/background_tasks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:primitives/primitives.dart';

final class _FailingStore extends InMemorySharedPreferencesStore {
  final bool throws;
  _FailingStore({this.throws = false}) : super.empty();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (throws) throw Exception('sensitive platform detail');
    return false;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('an unset or unknown interval reads as one hour', () async {
    const store = SharedPreferencesBackgroundSyncIntervalRepository();
    expect(await store.read(), BackgroundSyncInterval.hour1);

    SharedPreferences.setMockInitialValues({
      'background_sync_interval': 'minutes7',
    });
    expect(await store.read(), BackgroundSyncInterval.hour1);
  });

  test('reread observes Off written outside the isolate cache', () async {
    const store = SharedPreferencesBackgroundSyncIntervalRepository();
    expect(await store.read(), BackgroundSyncInterval.hour1);
    await SharedPreferencesStorePlatform.instance.setValue(
      'String',
      'flutter.background_sync_interval',
      'off',
    );
    expect(await store.read(), BackgroundSyncInterval.off);
  });

  test('a chosen interval survives a reread', () async {
    const store = SharedPreferencesBackgroundSyncIntervalRepository();
    expect(await store.write(BackgroundSyncInterval.minutes15), isA<Ok>());
    expect(await store.read(), BackgroundSyncInterval.minutes15);
    expect(await store.write(BackgroundSyncInterval.off), isA<Ok>());
    expect(await store.read(), BackgroundSyncInterval.off);
    expect(BackgroundSyncInterval.off.frequency, isNull);
  });

  for (final throws in [false, true]) {
    test(
      'failed preference write returns a typed failure (throws=$throws)',
      () async {
        SharedPreferencesStorePlatform.instance = _FailingStore(throws: throws);
        const store = SharedPreferencesBackgroundSyncIntervalRepository();
        expect(
          await store.write(BackgroundSyncInterval.off),
          isA<Err<void, BackgroundTasksFailure>>(),
        );
      },
    );
  }
}
