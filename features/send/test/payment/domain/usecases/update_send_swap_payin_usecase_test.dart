import 'package:swaps/order_swaps.dart';
import 'package:primitives/primitives.dart';
import 'package:send/src/payment/domain/send_failure.dart';
import 'package:send/src/payment/domain/usecases/update_send_swap_payin_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockOrderSwaps extends Mock implements OrderSwaps {}

void main() {
  late _MockOrderSwaps facade;
  late UpdateSendSwapPayinUsecase usecase;

  setUp(() {
    facade = _MockOrderSwaps();
    usecase = UpdateSendSwapPayinUsecase(facade);
  });

  test('maps an expired broadcast start to a confirmation failure', () async {
    when(() => facade.markBroadcastUnknown('local-1'))
        .thenAnswer((_) async => const Err(SwapOrderExpiredFailure('expired')));

    final result = await usecase.execute(
      localId: 'local-1',
      update: SendSwapPayinUpdate.broadcastStarted,
    );

    expect(
      (result as Err<OrderSwapRecord, SendFailure>).failure,
      isA<SendTransactionConfirmationFailure>(),
    );
  });

  test(
    'maps post-broadcast persistence errors to confirmation failure',
    () async {
      when(
        () => facade.markPayinBroadcast(
          localId: 'local-1',
          transactionId: 'txid-1',
        ),
      ).thenAnswer((_) async => const Err(SwapStorageFailure('disk')));

      final result = await usecase.execute(
        localId: 'local-1',
        update: SendSwapPayinUpdate.broadcastSucceeded,
        transactionId: 'txid-1',
      );

      expect(
        (result as Err<OrderSwapRecord, SendFailure>).failure,
        isA<SendTransactionConfirmationFailure>(),
      );
    },
  );

  test('replaces a previously prepared payin after options change', () async {
    when(
      () => facade.replacePreparedPayin(
        localId: 'local-1',
        signedTransaction: 'replacement-psbt',
        isPsbt: true,
      ),
    ).thenAnswer((_) async => Ok(_record()));

    final result = await usecase.execute(
      localId: 'local-1',
      update: SendSwapPayinUpdate.replaced,
      signedTransaction: 'replacement-psbt',
      isPsbt: true,
    );

    expect(result, isA<Ok<OrderSwapRecord, SendFailure>>());
    verify(
      () => facade.replacePreparedPayin(
        localId: 'local-1',
        signedTransaction: 'replacement-psbt',
        isPsbt: true,
      ),
    ).called(1);
  });
}

OrderSwapRecord _record() => OrderSwapRecord(
  localId: 'local-1',
  purpose: OrderSwapPurpose.sendLightning,
  environment: OrderSwapEnvironment.testnet,
  inNetwork: OrderSwapNetwork.bitcoin,
  outNetwork: OrderSwapNetwork.lightning,
  isInAmountFixed: false,
  requestedAmountSat: BigInt.from(1000),
  destination: 'invoice',
  fallback: 'fallback',
  createdAt: DateTime.utc(2026),
  localStatus: OrderSwapLocalStatus.creating,
);
