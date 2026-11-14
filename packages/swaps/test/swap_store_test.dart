import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show Err, Ok;
import 'package:swaps/src/data/models/swap_model.dart';
import 'package:swaps/src/data/swap_storage.dart';
import 'package:swaps/src/data/swap_store_impl.dart';
import 'package:swaps/src/domain/entities/swap.dart';
import 'package:swaps/src/domain/entities/swap_failure.dart';
import 'package:test/test.dart';

class _MockSwapStorage extends Mock implements SwapStorage {}

void main() {
  late _MockSwapStorage storage;
  late SwapStoreImpl store;

  SwapModel chain(
    String id, {
    required String status,
    String? sendTxid,
    String? receiveTxid,
    String? pendingLockupTx,
    String sendWalletId = 'w-liquid',
    String receiveWalletId = 'w-btc',
  }) => SwapModel.chain(
    id: id,
    type: SwapType.liquidToBitcoin.name,
    status: status,
    keyIndex: 0,
    creationTime: DateTime(2026, 7).millisecondsSinceEpoch,
    sendWalletId: sendWalletId,
    receiveWalletId: receiveWalletId,
    paymentAddress: 'lq1lockup',
    paymentAmount: 100000,
    sendTxid: sendTxid,
    receiveTxid: receiveTxid,
    pendingLockupTx: pendingLockupTx,
  );

  setUp(() {
    storage = _MockSwapStorage();
    store = SwapStoreImpl(storage: storage, isTestnet: false);
  });

  group('ongoing', () {
    test(
      'keeps swaps that still need driving and drops settled ones',
      () async {
        when(() => storage.fetchAll(isTestnet: false)).thenAnswer(
          (_) async => [
            chain('pending', status: 'pending'),
            chain(
              'confirming',
              status: 'failed',
              pendingLockupTx: 'signed-hex',
            ),
            chain('claimable', status: 'completed', sendTxid: 'lockup'),
            chain(
              'settled',
              status: 'completed',
              sendTxid: 'lockup',
              receiveTxid: 'claim',
            ),
            chain('abandoned', status: 'expired'),
          ],
        );

        final result = await store.ongoing();

        expect(
          result,
          isA<Ok<List<Swap>, SwapsFailure>>().having(
            (ok) => ok.value.map((s) => s.id),
            'ids',
            ['pending', 'confirming', 'claimable'],
          ),
        );
      },
    );

    test('filters by either side of a chain swap', () async {
      when(() => storage.fetchAll(isTestnet: false)).thenAnswer(
        (_) async => [
          chain('to-btc', status: 'pending'),
          chain(
            'elsewhere',
            status: 'pending',
            sendWalletId: 'w-other',
            receiveWalletId: 'w-other-btc',
          ),
        ],
      );

      final result = await store.ongoing(walletId: 'w-btc');

      expect(
        result,
        isA<Ok<List<Swap>, SwapsFailure>>().having(
          (ok) => ok.value.map((s) => s.id),
          'ids',
          ['to-btc'],
        ),
      );
    });

    test('a storage failure is a failure, not an empty list', () async {
      when(
        () => storage.fetchAll(isTestnet: false),
      ).thenThrow(Exception('locked'));

      final result = await store.ongoing();

      expect(result, isA<Err<List<Swap>, SwapsFailure>>());
    });
  });

  test('get reports a missing swap as a failure', () async {
    when(() => storage.fetch('gone')).thenAnswer((_) async => null);

    final result = await store.get('gone');

    expect(result, isA<Err<Swap, SwapsFailure>>());
  });
}
