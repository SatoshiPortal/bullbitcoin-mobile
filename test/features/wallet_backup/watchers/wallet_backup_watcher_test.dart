import 'dart:async';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_publication.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_codec_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/build_wallet_backup_snapshot_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/manage_wallet_backup_state_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/publish_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/watchers/wallet_backup_watcher.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Publish extends Mock implements PublishWalletBackupUsecase {}

class _Snapshots extends Mock implements WalletBackupCodecRepository {}

class _State extends Mock implements WalletBackupStateRepository {}

void main() {
  late StreamController<void> ownerEvents, stateEvents;
  late _Publish publish;
  late _Snapshots snapshots;
  late _State state;
  var calls = 0;
  final epoch = DateTime.utc(2026, 9, 18);
  setUp(() {
    ownerEvents = StreamController<void>.broadcast(sync: true);
    stateEvents = StreamController<void>.broadcast(sync: true);
    publish = _Publish();
    snapshots = _Snapshots();
    state = _State();
    calls = 0;
    when(() => snapshots.changes).thenAnswer((_) => ownerEvents.stream);
    when(() => state.changes).thenAnswer((_) => stateEvents.stream);
    when(() => publish.execute()).thenAnswer((_) async {
      calls++;
      return const Ok(WalletBackupPublication.upToDate);
    });
  });
  tearDown(() async {
    await ownerEvents.close();
    await stateEvents.close();
  });
  WalletBackupWatcher create(FakeAsync time) => WalletBackupWatcher(
    publish: publish,
    watchSnapshot: WatchWalletBackupSnapshotUsecase(snapshots),
    watchState: WatchWalletBackupStateUsecase(state),
    now: () => epoch.add(time.elapsed),
  );

  test(
    'startup is single; bursts coalesce; there is no periodic publication',
    () => fakeAsync((time) {
      final watcher = create(time)
        ..start()
        ..start();
      time.elapse(const Duration(milliseconds: 500));
      expect(calls, 1);
      for (var i = 0; i < 50; i++) {
        ownerEvents.add(null);
        stateEvents.add(null);
      }
      time.elapse(const Duration(milliseconds: 499));
      expect(calls, 1);
      time.elapse(const Duration(milliseconds: 1));
      expect(calls, 2);
      time.elapse(const Duration(hours: 10));
      expect(calls, 2);
      unawaited(watcher.dispose());
      time.flushMicrotasks();
    }),
  );

  test(
    'triggers during a publication request only one later pass',
    () => fakeAsync((time) {
      final gate =
          Completer<Result<WalletBackupPublication, WalletBackupFailure>>();
      when(() => publish.execute()).thenAnswer((_) {
        calls++;
        return calls == 1
            ? gate.future
            : Future.value(const Ok(WalletBackupPublication.upToDate));
      });
      final watcher = create(time)..start();
      time.elapse(const Duration(milliseconds: 500));
      expect(calls, 1);
      expect(watcher.status.running, isTrue);
      for (var i = 0; i < 50; i++) {
        ownerEvents.add(null);
      }
      time.elapse(const Duration(seconds: 5));
      expect(calls, 1);
      gate.complete(const Ok(WalletBackupPublication.published));
      time.flushMicrotasks();
      time.elapse(const Duration(milliseconds: 500));
      expect(calls, 2);
      expect(watcher.status.running, isFalse);
      unawaited(watcher.dispose());
      time.flushMicrotasks();
    }),
  );

  test(
    'network retries are bounded and a later resume can try again',
    () => fakeAsync((time) {
      when(() => publish.execute()).thenAnswer((_) async {
        calls++;
        return const Err(WalletBackupNetworkFailure());
      });
      final watcher = create(time)..start();
      time.elapse(const Duration(hours: 1));
      expect(calls, 5);
      time.elapse(const Duration(hours: 1));
      expect(calls, 5);
      watcher.resume();
      time.elapse(const Duration(milliseconds: 500));
      expect(calls, 6);
      unawaited(watcher.dispose());
      time.flushMicrotasks();
    }),
  );

  test(
    'owner events and resume do not shorten the transport retry time',
    () => fakeAsync((time) {
      when(() => publish.execute()).thenAnswer((_) async {
        calls++;
        return calls == 1
            ? Err(
                WalletBackupRateLimitedFailure(
                  epoch.add(const Duration(minutes: 2)),
                ),
              )
            : const Ok(WalletBackupPublication.upToDate);
      });
      final watcher = create(time)..start();
      time.elapse(const Duration(seconds: 1));
      for (var i = 0; i < 20; i++) {
        ownerEvents.add(null);
        watcher.resume();
      }
      time.elapse(const Duration(seconds: 118));
      expect(calls, 1);
      time.elapse(const Duration(seconds: 1));
      expect(calls, 2);
      unawaited(watcher.dispose());
      time.flushMicrotasks();
    }),
  );

  test(
    'pending data gets another pass; a conflict waits for an external action',
    () => fakeAsync((time) {
      when(() => publish.execute()).thenAnswer((_) async {
        calls++;
        return calls == 1
            ? const Ok(WalletBackupPublication.pending)
            : const Err(WalletBackupConflictFailure());
      });
      final watcher = create(time)..start();
      time.elapse(const Duration(seconds: 1));
      expect(calls, 2);
      time.elapse(const Duration(hours: 1));
      expect(calls, 2);
      expect(watcher.status.result, isA<Err>());
      unawaited(watcher.dispose());
      time.flushMicrotasks();
    }),
  );

  test(
    'stop cancels subscriptions and retries; restart subscribes once',
    () => fakeAsync((time) {
      when(() => publish.execute()).thenAnswer((_) async {
        calls++;
        return const Err(WalletBackupNetworkFailure());
      });
      final watcher = create(time)..start();
      time.elapse(const Duration(seconds: 1));
      unawaited(watcher.stop());
      time.flushMicrotasks();
      ownerEvents.add(null);
      stateEvents.add(null);
      time.elapse(const Duration(hours: 1));
      expect(calls, 1);
      watcher.start();
      time.elapse(const Duration(milliseconds: 500));
      expect(calls, 2);
      unawaited(watcher.dispose());
      time.flushMicrotasks();
      expect(time.nonPeriodicTimerCount, 0);
    }),
  );

  test('stop returns while an async owner is waiting for its next event', () {
    Stream<void> idleOwner() async* {
      await for (final _ in ownerEvents.stream) {
        yield null;
      }
    }

    when(() => snapshots.changes).thenAnswer((_) => idleOwner());
    fakeAsync((time) {
      final watcher = create(time)..start();
      time.elapse(const Duration(milliseconds: 500));
      var stopped = false;
      unawaited(watcher.stop().then((_) => stopped = true));
      time.flushMicrotasks();
      expect(stopped, isTrue);
      expect(time.nonPeriodicTimerCount, 0);
      ownerEvents.add(null);
      time.flushMicrotasks();
      unawaited(watcher.dispose());
      time.flushMicrotasks();
    });
  });

  test(
    'an owner notification error stops scheduling until resume reconnects',
    () => fakeAsync((time) {
      final watcher = create(time)..start();
      time.elapse(const Duration(milliseconds: 500));
      ownerEvents.addError(const FormatException('fixture owner failure'));
      time.flushMicrotasks();
      expect(watcher.status.result, isA<Err>());
      time.elapse(const Duration(hours: 1));
      expect(calls, 1);
      watcher.resume();
      time.elapse(const Duration(milliseconds: 500));
      expect(calls, 2);
      unawaited(watcher.dispose());
      time.flushMicrotasks();
    }),
  );

  test(
    'a missed owner signal is reconciled on resume',
    () => fakeAsync((time) {
      final watcher = create(time)..start();
      time.elapse(const Duration(milliseconds: 500));
      watcher.resume();
      time.elapse(const Duration(milliseconds: 500));
      expect(calls, 2);
      unawaited(watcher.dispose());
      time.flushMicrotasks();
    }),
  );
}
