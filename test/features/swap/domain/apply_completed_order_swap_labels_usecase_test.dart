import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_network.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_record.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:bb_mobile/features/swap/domain/usecases/apply_completed_order_swap_labels_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/get_order_swaps_awaiting_labels_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/mark_order_swap_labels_applied_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetOrders extends Mock
    implements GetOrderSwapsAwaitingLabelsUsecase {}

class _MockMarkApplied extends Mock
    implements MarkOrderSwapLabelsAppliedUsecase {}

class _MockWalletTransactions extends Mock
    implements WalletTransactionRepository {}

class _MockLabelsFacade extends Mock implements LabelsFacade {}

void main() {
  late _MockGetOrders getOrders;
  late _MockMarkApplied markApplied;
  late _MockWalletTransactions walletTransactions;
  late _MockLabelsFacade labelsFacade;
  late ApplyCompletedOrderSwapLabelsUsecase usecase;
  final now = DateTime.utc(2026, 8, 5, 12);

  setUpAll(() {
    registerFallbackValue(
      NewLabel.tx(transactionId: 'fallback', label: 'fallback'),
    );
  });

  setUp(() {
    getOrders = _MockGetOrders();
    markApplied = _MockMarkApplied();
    walletTransactions = _MockWalletTransactions();
    labelsFacade = _MockLabelsFacade();
    usecase = ApplyCompletedOrderSwapLabelsUsecase(
      getOrders,
      markApplied,
      walletTransactions,
      labelsFacade,
      now: () => now,
    );
    when(
      () => getOrders.execute(purpose: OrderSwapPurpose.receiveLightning),
    ).thenAnswer((_) async => const Ok([]));
  });

  test('does not label a completed swap before wallet confirmation', () async {
    final order = _record();
    when(
      () => getOrders.execute(purpose: OrderSwapPurpose.sendLightning),
    ).thenAnswer((_) async => Ok([order]));
    when(
      () => walletTransactions.getWalletTransaction(
        'payin-tx',
        walletId: 'wallet-1',
      ),
    ).thenAnswer((_) async => _transaction(WalletTransactionStatus.pending));

    final result = await usecase.execute();

    expect((result as Ok<int, SwapFailure>).value, 0);
    verifyNever(() => labelsFacade.store(any()));
    verifyNever(
      () => markApplied.execute(
        localId: any(named: 'localId'),
        appliedAt: any(named: 'appliedAt'),
      ),
    );
  });

  test('stores system and user labels after completion and one conf', () async {
    final order = _record();
    when(
      () => getOrders.execute(purpose: OrderSwapPurpose.sendLightning),
    ).thenAnswer((_) async => Ok([order]));
    when(
      () => walletTransactions.getWalletTransaction(
        'payin-tx',
        walletId: 'wallet-1',
      ),
    ).thenAnswer((_) async => _transaction(WalletTransactionStatus.confirmed));
    var labelId = 0;
    when(() => labelsFacade.store(any())).thenAnswer((invocation) async {
      final label = invocation.positionalArguments.single as NewLabel;
      return Ok(
        Label.tx(
          id: labelId++,
          transactionId: label.reference,
          label: label.label,
          origin: label.origin,
        ),
      );
    });
    when(
      () => markApplied.execute(localId: 'local-1', appliedAt: now),
    ).thenAnswer((_) async => Ok(order.withLabelsAppliedAt(now)));

    final result = await usecase.execute();

    expect((result as Ok<int, SwapFailure>).value, 1);
    final labels = verify(
      () => labelsFacade.store(captureAny()),
    ).captured.cast<NewLabel>();
    expect(labels.map((label) => label.label), [
      LabelSystem.swaps.label,
      'coffee',
    ]);
    expect(labels.every((label) => label.reference == 'payin-tx'), isTrue);
    verify(
      () => markApplied.execute(localId: 'local-1', appliedAt: now),
    ).called(1);
  });

  test('labels a confirmed Lightning receive payout', () async {
    final order = _receiveRecord();
    when(
      () => getOrders.execute(purpose: OrderSwapPurpose.sendLightning),
    ).thenAnswer((_) async => const Ok([]));
    when(
      () => getOrders.execute(purpose: OrderSwapPurpose.receiveLightning),
    ).thenAnswer((_) async => Ok([order]));
    when(
      () => walletTransactions.getWalletTransaction(
        'payout-tx',
        walletId: 'wallet-1',
      ),
    ).thenAnswer((_) async => _transaction(WalletTransactionStatus.confirmed));
    when(() => labelsFacade.store(any())).thenAnswer(
      (_) async => Ok(
        Label.tx(
          id: 1,
          transactionId: 'payout-tx',
          label: 'swap',
          origin: 'wallet-1',
        ),
      ),
    );
    when(
      () => markApplied.execute(localId: 'receive-local', appliedAt: now),
    ).thenAnswer((_) async => Ok(order.withLabelsAppliedAt(now)));

    final result = await usecase.execute();

    expect((result as Ok<int, SwapFailure>).value, 1);
    final labels = verify(
      () => labelsFacade.store(captureAny()),
    ).captured.cast<NewLabel>();
    expect(labels.every((label) => label.reference == 'payout-tx'), isTrue);
  });
}

OrderSwapRecord _record() => OrderSwapRecord(
  localId: 'local-1',
  purpose: OrderSwapPurpose.sendLightning,
  environment: OrderSwapEnvironment.testnet,
  inNetwork: OrderSwapNetwork.liquid,
  outNetwork: OrderSwapNetwork.lightning,
  isInAmountFixed: false,
  requestedAmountSat: BigInt.from(1000),
  sourceWalletId: 'wallet-1',
  destination: 'invoice',
  fallback: 'fallback',
  order: OrderSwap(
    orderId: 'order-1',
    orderNumber: 1,
    inNetwork: OrderSwapNetwork.liquid,
    outNetwork: OrderSwapNetwork.lightning,
    payinAmountSat: BigInt.from(1010),
    payoutAmountSat: BigInt.from(1000),
    payinCurrency: 'LBTC',
    payoutCurrency: 'BTCLN',
    payinMethod: 'Liquid',
    payoutMethod: 'Lightning',
    orderType: 'Swap',
    orderStatus: 'Completed',
    payinStatus: 'Completed',
    payoutStatus: 'Completed',
    messageCode: 'ORDER_COMPLETED',
    liquidTransactionId: 'payin-tx',
    createdAt: DateTime.utc(2026, 8, 5, 11),
    confirmationDeadline: DateTime.utc(2026, 8, 5, 11, 5),
    completedAt: DateTime.utc(2026, 8, 5, 11, 4),
  ),
  localPayinTransactionId: 'payin-tx',
  createdAt: DateTime.utc(2026, 8, 5, 11),
  localStatus: OrderSwapLocalStatus.completed,
  note: 'coffee',
);

OrderSwapRecord _receiveRecord() => OrderSwapRecord(
  localId: 'receive-local',
  purpose: OrderSwapPurpose.receiveLightning,
  environment: OrderSwapEnvironment.testnet,
  inNetwork: OrderSwapNetwork.lightning,
  outNetwork: OrderSwapNetwork.liquid,
  isInAmountFixed: true,
  requestedAmountSat: BigInt.from(1000),
  destinationWalletId: 'wallet-1',
  destination: 'tlq1-destination',
  fallback: 'tlq1-destination',
  order: OrderSwap(
    orderId: 'receive-order',
    orderNumber: 2,
    inNetwork: OrderSwapNetwork.lightning,
    outNetwork: OrderSwapNetwork.liquid,
    payinAmountSat: BigInt.from(1000),
    payoutAmountSat: BigInt.from(990),
    payinCurrency: 'BTCLN',
    payoutCurrency: 'LBTC',
    payinMethod: 'Lightning',
    payoutMethod: 'Liquid',
    orderType: 'Swap',
    orderStatus: 'Completed',
    payinStatus: 'Completed',
    payoutStatus: 'Completed',
    messageCode: 'ORDER_COMPLETED',
    liquidTransactionId: 'payout-tx',
    createdAt: DateTime.utc(2026, 8, 5, 11),
    confirmationDeadline: DateTime.utc(2026, 8, 5, 11, 5),
    completedAt: DateTime.utc(2026, 8, 5, 11, 4),
  ),
  createdAt: DateTime.utc(2026, 8, 5, 11),
  localStatus: OrderSwapLocalStatus.completed,
  note: 'coffee',
);

WalletTransaction _transaction(WalletTransactionStatus status) =>
    WalletTransaction(
      walletId: 'wallet-1',
      network: Network.liquidTestnet,
      direction: WalletTransactionDirection.outgoing,
      status: status,
      txId: 'payin-tx',
      amountSat: 1010,
      feeSat: 10,
      vsize: 100,
      inputs: const [],
      outputs: const [],
      isRbf: false,
      confirmationTime: status == WalletTransactionStatus.confirmed
          ? DateTime.utc(2026, 8, 5, 12)
          : null,
    );
