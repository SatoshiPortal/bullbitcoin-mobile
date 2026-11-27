import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:swap_feature/testing.dart';
import 'package:swaps/order_swaps.dart';
import 'package:swaps/swaps.dart' show Autoswap, AutoswapFailure;
import 'package:sync/sync.dart' show WalletKey;

class _Refresh extends Mock implements ScheduleOrderSwapRefreshUsecase {}

class _Autoswap extends Mock implements Autoswap {}

WalletKey get _liquid =>
    WalletKey(id: 'liquid', network: LiquidNetwork.testnet);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StreamController<WalletKey> syncs;
  late _Autoswap autoswap;
  late _Refresh refresh;
  late Completer<Result<String, AutoswapFailure>> running;
  late SwapWatchers watchers;

  setUp(() {
    syncs = StreamController<WalletKey>.broadcast();
    autoswap = _Autoswap();
    refresh = _Refresh();
    running = Completer<Result<String, AutoswapFailure>>();
    when(() => autoswap.execute()).thenAnswer((_) => running.future);
    when(() => refresh.execute())
        .thenAnswer((_) async => const OrderSwapPollingAttempt());
    watchers = SwapWatchers(
      OrderSwapWatcher(refresh),
      AutoswapWatcher(syncs.stream, autoswap),
    );
    addTearDown(() async {
      if (!running.isCompleted) running.complete(const Ok('done'));
      await watchers.dispose();
      await syncs.close();
    });
  });

  test(
    'suspend waits for an autoswap in progress and resume restarts once',
    () async {
      watchers.start(watchOrders: true, watchAutoswap: true);
      syncs.add(_liquid);
      await pumpEventQueue();
      verify(() => autoswap.execute()).called(1);

      var confirmed = false;
      final suspending = watchers.suspend().whenComplete(
        () => confirmed = true,
      );
      syncs.add(_liquid);
      await pumpEventQueue();
      expect(confirmed, isFalse, reason: 'the transfer is still running');
      verifyNever(() => autoswap.execute());

      watchers.resume();
      syncs.add(_liquid);
      await pumpEventQueue();
      verifyNever(() => autoswap.execute());

      running.complete(const Ok('order'));
      await suspending;
      expect(confirmed, isTrue);

      when(() => autoswap.execute()).thenAnswer((_) async => const Ok('next'));
      watchers.resume();
      watchers.resume();
      syncs.add(_liquid);
      await pumpEventQueue();
      verify(() => autoswap.execute()).called(1);
      expect(watchers.isWatchingOrders, isTrue);
    },
  );

  test('a start requested while suspended begins at the resume', () async {
    final suspending = watchers.suspend();
    await suspending;
    watchers.start(watchOrders: false, watchAutoswap: true);
    expect(watchers.isWatchingAutoswap, isFalse);
    when(() => autoswap.execute()).thenAnswer((_) async => const Ok('x'));
    watchers.resume();
    syncs.add(_liquid);
    await pumpEventQueue();
    verify(() => autoswap.execute()).called(1);
  });
}
