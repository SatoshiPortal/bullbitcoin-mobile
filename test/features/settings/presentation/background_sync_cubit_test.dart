import 'dart:async';

import 'package:background_tasks/background_tasks.dart';
import 'package:bb_mobile/features/settings/data/background_sync_repository_impl.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/get_background_sync_interval_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_background_sync_interval_usecase.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/background_sync_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class _Store implements BackgroundSyncIntervalStore {
  BackgroundSyncInterval value = BackgroundSyncInterval.hour1;
  bool failWrite = false;

  @override
  Future<BackgroundSyncInterval> read() async => value;

  @override
  Future<void> write(BackgroundSyncInterval interval) async {
    if (failWrite) throw StateError('disk full');
    value = interval;
  }
}

void main() {
  late _Store store;
  late int reschedules;
  late bool failReschedule;

  BackgroundSyncCubit cubit() {
    final repository = BackgroundSyncRepositoryImpl(
      store: store,
      reschedule: () async {
        reschedules++;
        if (failReschedule) throw StateError('workmanager');
      },
    );
    return BackgroundSyncCubit(
      getBackgroundSyncIntervalUsecase: GetBackgroundSyncIntervalUsecase(
        repository: repository,
      ),
      setBackgroundSyncIntervalUsecase: SetBackgroundSyncIntervalUsecase(
        repository: repository,
      ),
    );
  }

  setUp(() {
    store = _Store();
    reschedules = 0;
    failReschedule = false;
  });

  test('a choice is saved and applied to the schedule', () async {
    final subject = cubit();
    addTearDown(subject.close);
    await subject.load();
    expect(subject.state.interval, BackgroundSyncInterval.hour1);

    await subject.choose(BackgroundSyncInterval.minutes15);

    expect(store.value, BackgroundSyncInterval.minutes15);
    expect(reschedules, 1);
    expect(subject.state.interval, BackgroundSyncInterval.minutes15);
    expect(subject.state.failure, isNull);
  });

  test('an unsaved choice shows the previous interval', () async {
    store.failWrite = true;
    final subject = cubit();
    addTearDown(subject.close);
    await subject.load();

    await subject.choose(BackgroundSyncInterval.off);

    expect(subject.state.interval, BackgroundSyncInterval.hour1);
    expect(subject.state.failure, isA<SettingsStorageFailure>());
    expect(reschedules, 0);
  });

  test('a saved choice stays shown when rescheduling fails', () async {
    failReschedule = true;
    final subject = cubit();
    addTearDown(subject.close);
    await subject.load();

    await subject.choose(BackgroundSyncInterval.minutes30);

    expect(store.value, BackgroundSyncInterval.minutes30);
    expect(subject.state.interval, BackgroundSyncInterval.minutes30);
    expect(subject.state.failure, isNotNull);
  });

  test(
    'a late failure of an earlier choice does not undo a later one',
    () async {
      final firstReschedule = Completer<void>();
      var calls = 0;
      final repository = BackgroundSyncRepositoryImpl(
        store: store,
        reschedule: () {
          calls++;
          return calls == 1 ? firstReschedule.future : Future.value();
        },
      );
      final subject = BackgroundSyncCubit(
        getBackgroundSyncIntervalUsecase: GetBackgroundSyncIntervalUsecase(
          repository: repository,
        ),
        setBackgroundSyncIntervalUsecase: SetBackgroundSyncIntervalUsecase(
          repository: repository,
        ),
      );
      addTearDown(subject.close);
      await subject.load();

      final first = subject.choose(BackgroundSyncInterval.minutes15);
      await subject.choose(BackgroundSyncInterval.hours6);
      firstReschedule.completeError(StateError('workmanager'));
      await first;

      expect(subject.state.interval, BackgroundSyncInterval.hours6);
      expect(subject.state.failure, isNull);
    },
  );

  test('overlapping failed writes fall back to the saved interval', () async {
    final writes = <Completer<void>>[];
    final repository = BackgroundSyncRepositoryImpl(
      store: _GatedStore(store, writes),
      reschedule: () async {},
    );
    final subject = BackgroundSyncCubit(
      getBackgroundSyncIntervalUsecase: GetBackgroundSyncIntervalUsecase(
        repository: repository,
      ),
      setBackgroundSyncIntervalUsecase: SetBackgroundSyncIntervalUsecase(
        repository: repository,
      ),
    );
    addTearDown(subject.close);
    await subject.load();

    final first = subject.choose(BackgroundSyncInterval.minutes15);
    final second = subject.choose(BackgroundSyncInterval.off);
    await pumpEventQueue();
    for (final write in writes) {
      write.completeError(StateError('disk full'));
    }
    await Future.wait([first, second]);

    expect(subject.state.interval, BackgroundSyncInterval.hour1);
    expect(store.value, BackgroundSyncInterval.hour1);
  });
}

class _GatedStore implements BackgroundSyncIntervalStore {
  final _Store inner;
  final List<Completer<void>> writes;

  _GatedStore(this.inner, this.writes);

  @override
  Future<BackgroundSyncInterval> read() => inner.read();

  @override
  Future<void> write(BackgroundSyncInterval interval) {
    final gate = Completer<void>();
    writes.add(gate);
    return gate.future;
  }
}
