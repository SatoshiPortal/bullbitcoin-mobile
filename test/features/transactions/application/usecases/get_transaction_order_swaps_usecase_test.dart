import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transaction_order_swaps_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSwapFacade extends Mock implements SwapFacade {}

void main() {
  late _MockSwapFacade swapFacade;
  late GetTransactionOrderSwapsUsecase usecase;

  setUp(() {
    swapFacade = _MockSwapFacade();
    usecase = GetTransactionOrderSwapsUsecase(swapFacade);
  });

  test('loads wallet order swaps through the public facade', () async {
    final order = _orderSwap();
    when(
      () => swapFacade.getOrders(walletId: 'wallet-1'),
    ).thenAnswer((_) async => Ok([order]));

    final result = await usecase.execute(walletId: 'wallet-1');

    expect(result, isA<Ok<List<OrderSwapRecord>, TransactionFailure>>());
    expect((result as Ok).value, [order]);
  });

  test('maps swap failures into the transaction family', () async {
    when(
      () => swapFacade.getOrders(walletId: any(named: 'walletId')),
    ).thenAnswer(
      (_) async => const Err(SwapStorageFailure('database unavailable')),
    );

    final failure =
        (await usecase.execute(walletId: 'wallet-1') as Err).failure;

    expect(failure, isA<TransactionSwapUnavailableFailure>());
    expect(
      failure.logMessage,
      isNot(contains('database unavailable')),
      reason:
          'the swap layer'
          's own reason must not travel on our failure',
    );
  });
}

OrderSwapRecord _orderSwap() => OrderSwapRecord(
  localId: 'local-1',
  purpose: OrderSwapPurpose.sendLightning,
  environment: OrderSwapEnvironment.testnet,
  inNetwork: OrderSwapNetwork.bitcoin,
  outNetwork: OrderSwapNetwork.lightning,
  isInAmountFixed: false,
  requestedAmountSat: BigInt.from(100000),
  sourceWalletId: 'wallet-1',
  destination: 'invoice',
  fallback: 'fallback',
  createdAt: DateTime.utc(2026, 8, 6),
  localStatus: OrderSwapLocalStatus.creating,
);
