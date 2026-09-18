import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/transactions/application/usecases/watch_transaction_order_swap_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSwapFacade extends Mock implements SwapFacade {}

void main() {
  late _MockSwapFacade swapFacade;
  late WatchTransactionOrderSwapUsecase usecase;

  setUp(() {
    swapFacade = _MockSwapFacade();
    usecase = WatchTransactionOrderSwapUsecase(swapFacade);
  });

  test('wraps each event in Ok', () async {
    when(
      () => swapFacade.watchOrder('local-1'),
    ).thenAnswer((_) => Stream.value(Ok(_record())));

    final emitted = await usecase.execute('local-1').toList();

    expect(
      (emitted.single as Ok<OrderSwapRecord, TransactionFailure>).value.localId,
      'local-1',
    );
  });

  test('carries a watcher failure as a value, never a throw', () async {
    when(() => swapFacade.watchOrder('local-1')).thenAnswer(
      (_) => Stream.value(
        const Err(
          SwapStorageFailure('sqlite: database disk image is malformed'),
        ),
      ),
    );

    final emitted = await usecase.execute('local-1').toList();

    final failure = (emitted.single as Err).failure as TransactionFailure;
    expect(failure, isA<TransactionSwapUnavailableFailure>());
    expect(failure, isNot(isA<SwapFailure>()));
    expect(failure.logMessage, isNot(contains('sqlite')));
  });
}

OrderSwapRecord _record() => OrderSwapRecord(
  localId: 'local-1',
  purpose: OrderSwapPurpose.transfer,
  environment: OrderSwapEnvironment.testnet,
  inNetwork: OrderSwapNetwork.liquid,
  outNetwork: OrderSwapNetwork.bitcoin,
  isInAmountFixed: false,
  requestedAmountSat: BigInt.from(103000),
  sourceWalletId: 'wallet-1',
  destinationWalletId: 'wallet-2',
  destination: 'tb1destination',
  fallback: 'tlq1fallback',
  // The entity rejects payoutInProgress without a server order, so the
  // fixture has to be a record that could actually exist.
  order: OrderSwap(
    orderId: 'order-1',
    orderNumber: 1,
    inNetwork: OrderSwapNetwork.liquid,
    outNetwork: OrderSwapNetwork.bitcoin,
    payinAmountSat: BigInt.from(104030),
    payoutAmountSat: BigInt.from(103000),
    payinCurrency: 'LBTC',
    payoutCurrency: 'BTC',
    payinMethod: 'Liquid',
    payoutMethod: 'Bitcoin',
    orderType: 'Swap',
    orderStatus: 'In progress',
    payinStatus: 'Completed',
    payoutStatus: 'In progress',
    messageCode: 'PAYOUT_IN_PROGRESS',
    createdAt: DateTime.utc(2026),
    confirmationDeadline: DateTime.utc(2026, 1, 1, 0, 5),
  ),
  createdAt: DateTime.utc(2026),
  localStatus: OrderSwapLocalStatus.payoutInProgress,
);
