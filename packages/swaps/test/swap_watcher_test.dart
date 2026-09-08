import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:swaps/src/domain/entities/swap.dart';
import 'package:swaps/src/domain/swap_repository.dart';
import 'package:swaps/src/domain/swap_watcher.dart';
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

  test(
    'acts per status: canCoop coop-signs, terminal states do nothing',
    () async {
      await watcher.processSwap(chainSwap(SwapStatus.canCoop));
      verify(() => repo.coopSign(any())).called(1);

      await watcher.processSwap(chainSwap(SwapStatus.refunded));
      await watcher.processSwap(chainSwap(SwapStatus.failed));
      verifyNever(() => repo.claim(any()));
      verifyNever(() => repo.refund(any()));
    },
  );

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

  test('a live update drives the swap', () async {
    await watcher.start();
    updates.add(chainSwap(SwapStatus.refundable));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    verify(() => repo.refund(any())).called(1);
  });
}
