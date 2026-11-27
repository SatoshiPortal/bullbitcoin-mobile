import 'package:sync/sync.dart' show WalletKey;
import 'package:primitives/primitives.dart' show BitcoinNetwork, LiquidNetwork;

import 'dart:async';

import 'package:primitives/primitives.dart' show Ok, Result;
import 'package:swap_feature/testing.dart';
import 'package:swaps/swaps.dart' show Autoswap, AutoswapFailure;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockExecuteAutoswap extends Mock implements Autoswap {}

WalletKey _wallet({required bool liquid}) => WalletKey(
  id: liquid ? 'liquid' : 'bitcoin',
  network: liquid ? LiquidNetwork.testnet : BitcoinNetwork.testnet,
);

void main() {
  late StreamController<WalletKey> syncs;
  late _MockExecuteAutoswap executeAutoswap;
  late AutoswapWatcher watcher;

  setUp(() {
    syncs = StreamController<WalletKey>.broadcast();
    executeAutoswap = _MockExecuteAutoswap();
    watcher = AutoswapWatcher(syncs.stream, executeAutoswap)..start();
  });

  tearDown(() async {
    await watcher.dispose();
    await syncs.close();
  });

  test('runs only after a Liquid wallet sync', () async {
    when(() => executeAutoswap.execute())
        .thenAnswer((_) async => const Ok('order'));

    syncs.add(_wallet(liquid: false));
    await pumpEventQueue();
    verifyNever(() => executeAutoswap.execute());

    syncs.add(_wallet(liquid: true));
    await pumpEventQueue();
    verify(() => executeAutoswap.execute()).called(1);
  });

  test('serializes repeated Liquid sync notifications', () async {
    final execution = Completer<Result<String, AutoswapFailure>>();
    when(() => executeAutoswap.execute()).thenAnswer((_) => execution.future);

    syncs.add(_wallet(liquid: true));
    syncs.add(_wallet(liquid: true));
    await pumpEventQueue();

    verify(() => executeAutoswap.execute()).called(1);
    execution.complete(const Ok('order'));
  });

  test('can restart after its subscription has stopped', () async {
    when(() => executeAutoswap.execute())
        .thenAnswer((_) async => const Ok('order'));
    await watcher.dispose();
    watcher.start();
    syncs.add(_wallet(liquid: true));
    await pumpEventQueue();
    verify(() => executeAutoswap.execute()).called(1);
  });

  test('does not restart while an admitted execution is draining', () async {
    final execution = Completer<Result<String, AutoswapFailure>>();
    when(() => executeAutoswap.execute()).thenAnswer((_) => execution.future);
    syncs.add(_wallet(liquid: true));
    await pumpEventQueue();
    verify(() => executeAutoswap.execute()).called(1);

    final stopping = watcher.dispose();
    watcher.start();
    syncs.add(_wallet(liquid: true));
    await pumpEventQueue();
    verifyNever(() => executeAutoswap.execute());

    execution.complete(const Ok('order'));
    await stopping;
    watcher.start();
    syncs.add(_wallet(liquid: true));
    await pumpEventQueue();
    verify(() => executeAutoswap.execute()).called(1);
  });
}
