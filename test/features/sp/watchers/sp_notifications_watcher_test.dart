import 'package:primitives/primitives.dart';
import 'dart:async';

import 'package:bb_mobile/features/sp/domain/entities/sp_balance.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_wallet.dart';
import 'package:bb_mobile/features/sp/watchers/sp_notifications_watcher.dart';
import 'package:bb_mobile/features/sp/domain/usecases/ensure_sp_session_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/watch_sp_notifications_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchSpNotificationsUsecase extends Mock
    implements WatchSpNotificationsUsecase {}

class _MockEnsureSpSessionUsecase extends Mock
    implements EnsureSpSessionUsecase {}

SpWallet _wallet() => SpWallet(
  spAddress: 'sp1qtest',
  balance: SpBalance(confirmedSat: Sats.zero, totalUnifiedSat: Sats.zero),
  isScanning: false,
);

void main() {
  late _MockWatchSpNotificationsUsecase watchUsecase;
  late _MockEnsureSpSessionUsecase ensureUsecase;
  late SpNotificationsWatcher watcher;

  setUp(() {
    watchUsecase = _MockWatchSpNotificationsUsecase();
    ensureUsecase = _MockEnsureSpSessionUsecase();
    watcher = SpNotificationsWatcher(
      watchSpNotificationsUsecase: watchUsecase,
      ensureSpSessionUsecase: ensureUsecase,
    );
  });

  test('forwards notifications from the source', () async {
    final source = StreamController<SpNotification>.broadcast();
    addTearDown(source.close);
    when(() => watchUsecase.execute()).thenAnswer((_) => source.stream);

    final events = <SpNotification>[];
    watcher.watch(onReconnect: () {}).listen(events.add);

    source.add(const SpScanStarted(1, 2));
    await Future<void>.delayed(Duration.zero);

    expect(events, hasLength(1));
    await watcher.dispose();
  });

  test('forwards source events emitted synchronously on listen', () async {
    late StreamController<SpNotification> source;
    source = StreamController<SpNotification>.broadcast(
      onListen: () {
        source.add(
          const SpHeaderProgressCompleted(SpHeaderValidationPhase.replay),
        );
      },
    );
    addTearDown(source.close);
    when(() => watchUsecase.execute()).thenAnswer((_) => source.stream);

    final event = watcher.watch(onReconnect: () {}).first;

    expect(
      await event.timeout(
        const Duration(seconds: 5),
        onTimeout: () => fail('no notification was forwarded on listen'),
      ),
      const SpHeaderProgressCompleted(SpHeaderValidationPhase.replay),
    );
    await watcher.dispose();
  });

  test('re-establishes and reconnects when the source closes', () async {
    final first = StreamController<SpNotification>.broadcast();
    final second = StreamController<SpNotification>.broadcast();
    addTearDown(second.close);
    final sources = [first.stream, second.stream];
    var call = 0;
    when(() => watchUsecase.execute()).thenAnswer((_) => sources[call++]);
    when(() => ensureUsecase.execute()).thenAnswer((_) async => Ok(_wallet()));

    final reconnected = Completer<void>();
    var reconnects = 0;
    watcher
        .watch(
          onReconnect: () {
            reconnects++;
            reconnected.complete();
          },
        )
        .listen((_) {});

    await first.close();
    await reconnected.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => fail('the watcher never re-subscribed'),
    );

    verify(() => ensureUsecase.execute()).called(1);
    verify(() => watchUsecase.execute()).called(2);
    expect(reconnects, 1);
    await watcher.dispose();
  });

  test('does not re-subscribe when the wallet is gone', () async {
    final source = StreamController<SpNotification>.broadcast();
    when(() => watchUsecase.execute()).thenAnswer((_) => source.stream);
    // The establish attempt is the deterministic signal that the watcher has
    // reacted to the close; nothing must follow it.
    final establishAttempted = Completer<void>();
    when(() => ensureUsecase.execute()).thenAnswer((_) async {
      establishAttempted.complete();
      return const Ok(null);
    });

    var reconnects = 0;
    watcher.watch(onReconnect: () => reconnects++).listen((_) {});

    await source.close();
    await establishAttempted.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => fail('the watcher never tried to re-establish'),
    );
    await pumpEventQueue();

    verify(() => ensureUsecase.execute()).called(1);
    verify(() => watchUsecase.execute()).called(1);
    expect(reconnects, 0);
    await watcher.dispose();
  });
}
