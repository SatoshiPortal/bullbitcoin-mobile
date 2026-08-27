import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transaction_order_swap_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSwapFacade extends Mock implements SwapFacade {}

void main() {
  late _MockSwapFacade swapFacade;
  late GetTransactionOrderSwapUsecase usecase;

  setUp(() {
    swapFacade = _MockSwapFacade();
    usecase = GetTransactionOrderSwapUsecase(swapFacade);
  });

  test('loads an Exchange order by its local record id', () async {
    when(
      () => swapFacade.getOrder('local-1'),
    ).thenAnswer((_) async => Ok(_record()));

    final result = await usecase.execute('local-1');

    expect(result.localId, 'local-1');
    expect(result.orderId, 'order-1');
  });

  test('throws when the local record id is absent', () async {
    when(() => swapFacade.getOrder('missing')).thenAnswer(
      (_) async => const Err(SwapOrderNotFoundFailure('Local order not found')),
    );

    await expectLater(
      usecase.execute('missing'),
      throwsA(isA<TransactionNotFoundError>()),
    );
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
