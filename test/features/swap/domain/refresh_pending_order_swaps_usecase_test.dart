import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_network.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_record.dart';
import 'package:bb_mobile/features/swap/domain/repositories/order_swap_repository.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:bb_mobile/features/swap/domain/usecases/refresh_pending_order_swaps_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockOrderSwapRepository extends Mock implements OrderSwapRepository {}

void main() {
  late _MockOrderSwapRepository repository;

  setUp(() => repository = _MockOrderSwapRepository());

  test(
    'refreshes pending orders strictly serially with request spacing',
    () async {
      final first = _record('local-1', 'order-1');
      final second = _record('local-2', 'order-2');
      final firstRefresh = Completer<Result<OrderSwapRecord, SwapFailure>>();
      final delays = <Duration>[];
      when(
        repository.getPendingOrders,
      ).thenAnswer((_) async => Ok([first, second]));
      when(
        () => repository.refreshOrder('local-1'),
      ).thenAnswer((_) => firstRefresh.future);
      when(
        () => repository.refreshOrder('local-2'),
      ).thenAnswer((_) async => Ok(second));
      final usecase = RefreshPendingOrderSwapsUsecase(
        repository,
        delay: (duration) async => delays.add(duration),
      );

      final resultFuture = usecase.execute();
      await Future<void>.delayed(Duration.zero);
      verify(() => repository.refreshOrder('local-1')).called(1);
      verifyNever(() => repository.refreshOrder('local-2'));

      firstRefresh.complete(Ok(first));
      final result = await resultFuture;

      verify(() => repository.refreshOrder('local-2')).called(1);
      expect(delays, [const Duration(seconds: 1)]);
      final batch = (result as Ok<OrderSwapRefreshBatch, SwapFailure>).value;
      expect(batch.refreshed, [first, second]);
      expect(batch.failures, isEmpty);
    },
  );

  test('stops the batch when the global API rate limit is reached', () async {
    final first = _record('local-1', 'order-1');
    final second = _record('local-2', 'order-2');
    when(
      repository.getPendingOrders,
    ).thenAnswer((_) async => Ok([first, second]));
    when(() => repository.refreshOrder('local-1')).thenAnswer(
      (_) async =>
          const Err(SwapRateLimitedFailure(retryAfter: Duration(seconds: 2))),
    );
    final usecase = RefreshPendingOrderSwapsUsecase(
      repository,
      delay: (_) async {},
    );

    final result = await usecase.execute();

    verifyNever(() => repository.refreshOrder('local-2'));
    final batch = (result as Ok<OrderSwapRefreshBatch, SwapFailure>).value;
    expect(batch.failures.single, isA<SwapRateLimitedFailure>());
  });

  test('does not poll creation outcomes without a server order id', () async {
    final unknown = OrderSwapRecord(
      localId: 'local-1',
      purpose: OrderSwapPurpose.sendLightning,
      environment: OrderSwapEnvironment.testnet,
      inNetwork: OrderSwapNetwork.liquid,
      outNetwork: OrderSwapNetwork.lightning,
      isInAmountFixed: false,
      requestedAmountSat: BigInt.from(1000),
      destination: 'invoice',
      fallback: 'fallback',
      createdAt: DateTime.utc(2026),
      localStatus: OrderSwapLocalStatus.creationUnknown,
    );
    when(repository.getPendingOrders).thenAnswer((_) async => Ok([unknown]));
    final usecase = RefreshPendingOrderSwapsUsecase(repository);

    final result = await usecase.execute();

    verifyNever(() => repository.refreshOrder(any()));
    final batch = (result as Ok<OrderSwapRefreshBatch, SwapFailure>).value;
    expect(batch.pollableOrderCount, 0);
  });

  test('does not poll Funding orders unsupported by the swap summary', () async {
    final funding = _record(
      'local-1',
      'order-1',
      orderType: 'Funding',
    );
    when(repository.getPendingOrders).thenAnswer((_) async => Ok([funding]));
    final usecase = RefreshPendingOrderSwapsUsecase(repository);

    final result = await usecase.execute();

    verifyNever(() => repository.refreshOrder(any()));
    final batch = (result as Ok<OrderSwapRefreshBatch, SwapFailure>).value;
    expect(batch.pollableOrderCount, 0);
  });
}

OrderSwapRecord _record(
  String localId,
  String orderId, {
  String orderType = 'Swap',
}) => OrderSwapRecord(
  localId: localId,
  purpose: OrderSwapPurpose.sendLightning,
  environment: OrderSwapEnvironment.testnet,
  inNetwork: OrderSwapNetwork.liquid,
  outNetwork: OrderSwapNetwork.lightning,
  isInAmountFixed: false,
  requestedAmountSat: BigInt.from(1000),
  destination: 'invoice',
  fallback: 'fallback',
  order: OrderSwap(
    orderId: orderId,
    orderNumber: 1,
    inNetwork: OrderSwapNetwork.liquid,
    outNetwork: OrderSwapNetwork.lightning,
    payinAmountSat: BigInt.from(1010),
    payoutAmountSat: BigInt.from(1000),
    payinCurrency: 'LBTC',
    payoutCurrency: 'BTCLN',
    payinMethod: 'Liquid',
    payoutMethod: 'Lightning',
    orderType: orderType,
    orderStatus: 'Awaiting payment',
    payinStatus: 'In progress',
    payoutStatus: 'In progress',
    messageCode: 'ORDER_CREATED',
    createdAt: DateTime.utc(2026),
    confirmationDeadline: DateTime.utc(2026, 1, 1, 0, 5),
  ),
  createdAt: DateTime.utc(2026),
  localStatus: OrderSwapLocalStatus.awaitingUserConfirmation,
);
