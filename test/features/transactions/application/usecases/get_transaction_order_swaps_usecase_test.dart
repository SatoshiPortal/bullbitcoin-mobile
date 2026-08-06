import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transaction_order_swaps_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_error.dart';
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

    expect(result, [order]);
  });

  test('maps swap failures to a transaction error', () async {
    when(
      () => swapFacade.getOrders(walletId: any(named: 'walletId')),
    ).thenAnswer(
      (_) async => const Err(SwapStorageFailure('database unavailable')),
    );

    expect(
      () => usecase.execute(walletId: 'wallet-1'),
      throwsA(isA<TransactionError>()),
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
