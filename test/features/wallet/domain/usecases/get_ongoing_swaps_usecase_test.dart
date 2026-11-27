import 'package:swaps/swaps.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_ongoing_swaps_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSwapStore extends Mock implements SwapStore {}

List<Swap> _valueOf(Result<List<Swap>, WalletFailure> result) =>
    switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => fail('expected an Ok, got ${failure.runtimeType}'),
    };

Swap _chain(
  String id, {
  SwapStatus status = SwapStatus.paid,
  String? sendTxid = 'lockup',
  DateTime? created,
}) => Swap.chain(
  id: id,
  keyIndex: 0,
  type: SwapType.bitcoinToLiquid,
  status: status,
  environment: SwapEnvironment.mainnet,
  creationTime: created ?? DateTime.utc(2026),
  sendWalletId: 'w1',
  paymentAddress: 'bc1qexampleaddress',
  paymentAmount: 1000,
  sendTxid: sendTxid,
  receiveWalletId: 'w2',
);

Swap _unpaidInvoice() => Swap.lnReceive(
  id: 'invoice',
  keyIndex: 1,
  type: SwapType.lightningToLiquid,
  status: SwapStatus.pending,
  environment: SwapEnvironment.mainnet,
  creationTime: DateTime.utc(2026, 2),
  receiveWalletId: 'w2',
  invoice: '',
);

void main() {
  late _MockSwapStore swapStore;
  late GetOngoingSwapsUsecase usecase;

  setUp(() {
    swapStore = _MockSwapStore();
    usecase = GetOngoingSwapsUsecase(swapStore: swapStore);
  });

  test('lists the swaps in progress, newest first', () async {
    when(() => swapStore.ongoing()).thenAnswer(
      (_) async => Ok([
        _chain('older', created: DateTime.utc(2026, 1)),
        _chain('newer', created: DateTime.utc(2026, 3)),
      ]),
    );

    final swaps = _valueOf(await usecase.execute());

    expect(swaps.map((swap) => swap.id), ['newer', 'older']);
  });

  test('leaves out swaps nothing has moved for', () async {
    when(() => swapStore.ongoing()).thenAnswer(
      (_) async => Ok([
        _chain('dead', status: SwapStatus.pending, sendTxid: null),
        _unpaidInvoice(),
        _chain('sent', status: SwapStatus.pending),
      ]),
    );

    final swaps = _valueOf(await usecase.execute());

    expect(swaps.map((swap) => swap.id), ['sent']);
  });

  test('no swaps is an empty list, not a failure', () async {
    when(() => swapStore.ongoing()).thenAnswer((_) async => const Ok([]));

    expect(_valueOf(await usecase.execute()), isEmpty);
  });

  test('sanitizes a failed swap read', () async {
    when(() => swapStore.ongoing()).thenAnswer(
      (_) async => const Err(
        SwapsUnexpectedFailure(
          'boltz api 502 at https://api.boltz.exchange/v2',
        ),
      ),
    );

    final failure = switch (await usecase.execute()) {
      Ok() => fail('expected an Err, got Ok'),
      Err(:final failure) => failure,
    };
    expect(failure, isA<WalletUnexpectedFailure>());
    expect(failure.logMessage, isNot(contains('api.boltz.exchange')));
  });
}
