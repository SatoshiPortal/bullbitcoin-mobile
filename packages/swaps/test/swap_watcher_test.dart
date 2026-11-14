import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:swaps/src/domain/entities/swap.dart';
import 'package:swaps/src/domain/entities/swap_failure.dart';
import 'package:swaps/src/domain/swap_resolver.dart';
import 'package:swaps/src/domain/swap_store.dart';
import 'package:swaps/src/domain/swap_watcher.dart';
import 'package:test/test.dart';

class _MockSwapStore extends Mock implements SwapStore {}

class _MockSwapResolver extends Mock implements SwapResolver {}

void main() {
  late _MockSwapStore store;
  late _MockSwapResolver resolver;
  late SwapWatcher watcher;
  late StreamController<Swap> updates;

  Swap chainSwap(SwapStatus status, {String id = 'swap'}) => Swap.chain(
    id: id,
    keyIndex: 0,
    type: SwapType.liquidToBitcoin,
    status: status,
    environment: Environment.mainnet,
    creationTime: DateTime(2026, 7),
    sendWalletId: 'w-liquid',
    paymentAddress: 'lq1lockup',
    paymentAmount: 100000,
    sendTxid: 'lockup-txid',
  );

  Future<Result<Swap, SwapsFailure>> resolved(Invocation inv) async =>
      Ok(inv.positionalArguments[0] as Swap);

  setUpAll(() {
    registerFallbackValue(chainSwap(SwapStatus.refundable));
  });

  setUp(() {
    store = _MockSwapStore();
    resolver = _MockSwapResolver();
    updates = StreamController<Swap>.broadcast();
    when(() => resolver.updates).thenAnswer((_) => updates.stream);
    when(() => store.ongoing()).thenAnswer((_) async => const Ok([]));
    when(
      () => resolver.verifyCompletions(),
    ).thenAnswer((_) async => const Ok(null));
    when(() => resolver.listen(any())).thenAnswer((_) {});
    when(
      () => resolver.reconcile(any()),
    ).thenAnswer((_) async => const Ok(null));
    when(() => resolver.resolve(any())).thenAnswer(resolved);
    when(() => resolver.resolveScriptPath(any())).thenAnswer(resolved);
    watcher = SwapWatcher(
      store: store,
      resolvers: {SwapProvider.boltz: resolver},
    );
  });

  tearDown(() async {
    await watcher.stop();
    await updates.close();
  });

  test(
    'start verifies completions, then resolves every ongoing swap',
    () async {
      when(() => store.ongoing()).thenAnswer(
        (_) async => Ok([
          chainSwap(SwapStatus.refundable, id: 'a'),
          chainSwap(SwapStatus.claimable, id: 'b'),
        ]),
      );

      await watcher.start();

      verify(() => resolver.verifyCompletions()).called(1);
      verify(() => resolver.listen(['a', 'b'])).called(1);
      verify(() => resolver.reconcile(['a', 'b'])).called(1);
      verify(() => resolver.resolve(any())).called(2);
    },
  );

  test('an unreadable store drives nothing', () async {
    when(
      () => store.ongoing(),
    ).thenAnswer((_) async => const Err(SwapsUnexpectedFailure('db')));

    await watcher.start();

    verifyNever(() => resolver.reconcile(any()));
    verifyNever(() => resolver.resolve(any()));
  });

  test('a failed resolution backs off instead of hot-looping', () async {
    when(
      () => resolver.resolve(any()),
    ).thenAnswer((_) async => const Err(SwapsUnexpectedFailure('electrum')));
    final swap = chainSwap(SwapStatus.refundable);

    await watcher.processSwap(swap);
    await watcher.processSwap(swap);

    verify(() => resolver.resolve(any())).called(1);
  });

  test(
    'heartbeat retries resolution even when the Boltz backend is down',
    () async {
      when(
        () => resolver.reconcile(any()),
      ).thenAnswer((_) async => const Err(SwapsUnexpectedFailure('boltz')));
      when(
        () => store.ongoing(),
      ).thenAnswer((_) async => Ok([chainSwap(SwapStatus.refundable)]));
      watcher = SwapWatcher(
        store: store,
        resolvers: {SwapProvider.boltz: resolver},
        heartbeat: const Duration(milliseconds: 40),
      );

      await watcher.start();
      await Future<void>.delayed(const Duration(milliseconds: 110));

      expect(
        verify(() => resolver.resolve(any())).callCount,
        greaterThanOrEqualTo(2),
      );
    },
  );

  test('a live update drives the swap', () async {
    await watcher.start();
    updates.add(chainSwap(SwapStatus.refundable));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    verify(() => resolver.resolve(any())).called(1);
  });

  test('stop waits for an action already running', () async {
    final resolution = Completer<Result<Swap, SwapsFailure>>();
    when(() => resolver.resolve(any())).thenAnswer((_) => resolution.future);
    final swap = chainSwap(SwapStatus.claimable);
    unawaited(watcher.processSwap(swap));
    await Future<void>.delayed(Duration.zero);

    var stopped = false;
    final stopping = watcher.stop().then((_) => stopped = true);
    await Future<void>.delayed(Duration.zero);
    expect(stopped, isFalse);

    resolution.complete(Ok(swap));
    await stopping;
    expect(stopped, isTrue);
  });

  test('a stopped watcher acts on nothing until it runs again', () async {
    await watcher.stop();

    await watcher.processSwap(chainSwap(SwapStatus.claimable));
    verifyNever(() => resolver.resolve(any()));

    watcher.ensureRunning();
    await watcher.processSwap(chainSwap(SwapStatus.claimable));
    verify(() => resolver.resolve(any())).called(1);
  });

  group('retry', () {
    test('goes to the script path, not the cooperative resolution', () async {
      final swap = chainSwap(SwapStatus.refundable);

      final result = await watcher.retry(swap);

      expect(result, isA<Ok<Swap, SwapsFailure>>());
      verify(() => resolver.resolveScriptPath(swap)).called(1);
      verifyNever(() => resolver.resolve(any()));
    });

    test('waits for an action already in flight for the swap', () async {
      final resolution = Completer<Result<Swap, SwapsFailure>>();
      when(() => resolver.resolve(any())).thenAnswer((_) => resolution.future);
      final swap = chainSwap(SwapStatus.refundable);
      unawaited(watcher.processSwap(swap));
      await Future<void>.delayed(Duration.zero);

      var retried = false;
      final retrying = watcher.retry(swap).then((_) => retried = true);
      await Future<void>.delayed(Duration.zero);
      expect(retried, isFalse);
      verifyNever(() => resolver.resolveScriptPath(any()));

      resolution.complete(Ok(swap));
      await retrying;
      verify(() => resolver.resolveScriptPath(swap)).called(1);
    });

    test('a successful retry clears the backoff', () async {
      when(
        () => resolver.resolve(any()),
      ).thenAnswer((_) async => const Err(SwapsUnexpectedFailure('electrum')));
      final swap = chainSwap(SwapStatus.refundable);
      await watcher.processSwap(swap);

      await watcher.retry(swap);
      await watcher.processSwap(swap);

      verify(() => resolver.resolve(any())).called(2);
    });
  });
}
