import 'dart:async';

import 'package:bb_mobile/features/sp/domain/entities/sp_balance.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_wallet.dart';
import 'package:bb_mobile/features/sp/domain/sp_notifications_watcher.dart';
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
  balance: SpBalance(
    confirmedSat: BigInt.zero,
    totalUnifiedSat: BigInt.zero,
  ),
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

  test('re-establishes and reconnects when the source closes', () async {
    final first = StreamController<SpNotification>.broadcast();
    final second = StreamController<SpNotification>.broadcast();
    addTearDown(second.close);
    final sources = [first.stream, second.stream];
    var call = 0;
    when(() => watchUsecase.execute()).thenAnswer((_) => sources[call++]);
    when(() => ensureUsecase.execute()).thenAnswer((_) async => _wallet());

    var reconnects = 0;
    watcher.watch(onReconnect: () => reconnects++).listen((_) {});

    await first.close();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    verify(() => ensureUsecase.execute()).called(1);
    verify(() => watchUsecase.execute()).called(2);
    expect(reconnects, 1);
    await watcher.dispose();
  });

  test('does not re-subscribe when the wallet is gone', () async {
    final source = StreamController<SpNotification>.broadcast();
    when(() => watchUsecase.execute()).thenAnswer((_) => source.stream);
    when(() => ensureUsecase.execute()).thenAnswer((_) async => null);

    var reconnects = 0;
    watcher.watch(onReconnect: () => reconnects++).listen((_) {});

    await source.close();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    verify(() => ensureUsecase.execute()).called(1);
    verify(() => watchUsecase.execute()).called(1);
    expect(reconnects, 0);
    await watcher.dispose();
  });
}
