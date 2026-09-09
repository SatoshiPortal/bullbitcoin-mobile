import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:boltz_swaps/src/domain/entities/swap.dart';
import 'package:boltz_swaps/src/domain/swap_repository.dart';
import 'package:boltz_swaps/src/domain/swap_watcher.dart';
import 'package:test/test.dart';

class _MockSwapRepository extends Mock implements SwapRepository {}

void main() {
  late _MockSwapRepository repo;
  late SwapWatcher watcher;
  late StreamController<Swap> updates;

  Swap chainSwap(SwapStatus status, {String? refundTxid}) => Swap.chain(
    id: 'swap-${status.name}',
    keyIndex: 0,
    type: SwapType.liquidToBitcoin,
    status: status,
    environment: Environment.mainnet,
    creationTime: DateTime(2026, 7),
    sendWalletId: 'w-liquid',
    paymentAddress: 'lq1lockup',
    paymentAmount: 100000,
    sendTxid: 'lockup-txid',
    refundTxid: refundTxid,
  );

  setUpAll(() {
    registerFallbackValue(chainSwap(SwapStatus.refundable));
  });

  setUp(() {
    repo = _MockSwapRepository();
    updates = StreamController<Swap>.broadcast();
    when(() => repo.updates).thenAnswer((_) => updates.stream);
    when(
      () => repo.ongoing(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async => []);
    when(() => repo.ongoing()).thenAnswer((_) async => []);
    when(() => repo.verifyCompletions()).thenAnswer((_) async {});
    when(() => repo.listen(any())).thenAnswer((_) {});
    when(() => repo.reconcile(any())).thenAnswer((_) async {});
    when(() => repo.claim(any())).thenAnswer((_) async => 'claim-txid');
    when(() => repo.refund(any())).thenAnswer((_) async => 'refund-txid');
    when(() => repo.coopSign(any())).thenAnswer((_) async {});
    watcher = SwapWatcher(repo: repo);
  });

  tearDown(() async {
    await watcher.stop();
    await updates.close();
  });

  test('start verifies completions, then drives every ongoing swap', () async {
    when(() => repo.ongoing()).thenAnswer(
      (_) async => [
        chainSwap(SwapStatus.refundable),
        chainSwap(SwapStatus.claimable),
      ],
    );

    await watcher.start();

    verify(() => repo.verifyCompletions()).called(1);
    verify(() => repo.refund(any())).called(1);
    verify(() => repo.claim(any())).called(1);
    verify(() => repo.reconcile(any())).called(1);
  });

  test('acts per status: canCoop coop-signs submarine, claims chain, '
      'refunded does nothing', () async {
    await watcher.processSwap(
      Swap.lnSend(
        id: 'submarine-cancoop',
        keyIndex: 0,
        type: SwapType.liquidToLightning,
        status: SwapStatus.canCoop,
        environment: Environment.mainnet,
        creationTime: DateTime(2026, 7),
        sendWalletId: 'w-liquid',
        invoice: 'lnbc1',
        paymentAddress: 'lq1lockup',
        paymentAmount: 100000,
      ),
    );
    verify(() => repo.coopSign(any())).called(1);
    verifyNever(() => repo.claim(any()));

    // A chain swap parked at canCoop (restore maps claim.pending there) has
    // OUR claim pending — coopSign would no-op and strand it.
    await watcher.processSwap(chainSwap(SwapStatus.canCoop));
    verify(() => repo.claim(any())).called(1);

    await watcher.processSwap(chainSwap(SwapStatus.refunded));
    verifyNever(() => repo.claim(any()));
    verifyNever(() => repo.refund(any()));
  });

  test('drives the refund of failed/expired swaps with locked funds', () async {
    await watcher.processSwap(chainSwap(SwapStatus.failed));
    await watcher.processSwap(chainSwap(SwapStatus.expired));
    verify(() => repo.refund(any())).called(2);

    // Already refunded: nothing left to drive.
    await watcher.processSwap(
      chainSwap(SwapStatus.failed, refundTxid: 'refund-done'),
    );
    verifyNever(() => repo.refund(any()));
  });

  test('re-claims a completed swap without a recorded claim', () async {
    await watcher.processSwap(chainSwap(SwapStatus.completed));
    verify(() => repo.claim(any())).called(1);

    await watcher.processSwap(
      chainSwap(SwapStatus.completed, refundTxid: 'refund-done'),
    );
    verifyNever(() => repo.refund(any()));
  });

  test('a failed action backs off instead of hot-looping', () async {
    when(() => repo.refund(any())).thenThrow(Exception('electrum down'));
    final swap = chainSwap(SwapStatus.refundable);

    await watcher.processSwap(swap);
    await watcher.processSwap(swap);

    verify(() => repo.refund(any())).called(1);
  });

  test(
    'heartbeat retries actions even when the Boltz backend is down',
    () async {
      when(() => repo.reconcile(any())).thenThrow(Exception('boltz down'));
      when(
        () => repo.ongoing(),
      ).thenAnswer((_) async => [chainSwap(SwapStatus.refundable)]);
      watcher = SwapWatcher(
        repo: repo,
        heartbeat: const Duration(milliseconds: 40),
      );

      await watcher.start();
      await Future<void>.delayed(const Duration(milliseconds: 110));

      // Start sweep + at least one heartbeat sweep — refund must not depend
      // on reconcile succeeding or the backend re-emitting the swap.
      expect(
        verify(() => repo.refund(any())).callCount,
        greaterThanOrEqualTo(2),
      );
    },
  );

  test('a live update drives the swap', () async {
    await watcher.start();
    updates.add(chainSwap(SwapStatus.refundable));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    verify(() => repo.refund(any())).called(1);
  });
}
