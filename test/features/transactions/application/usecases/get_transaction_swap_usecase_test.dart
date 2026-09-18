import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transaction_swap_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/watch_transaction_swap_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetSwapUsecase extends Mock implements GetSwapUsecase {}

class _MockWatchSwapUsecase extends Mock implements WatchSwapUsecase {}

Swap _swap() => Swap.lnReceive(
  id: 'swap-1',
  keyIndex: 0,
  type: SwapType.lightningToBitcoin,
  status: SwapStatus.pending,
  environment: Environment.mainnet,
  creationTime: DateTime.utc(2026),
  receiveWalletId: 'w1',
  invoice: 'lnbc1',
);

void main() {
  group('GetTransactionSwapUsecase', () {
    late _MockGetSwapUsecase getSwap;
    late GetTransactionSwapUsecase usecase;

    setUp(() {
      getSwap = _MockGetSwapUsecase();
      usecase = GetTransactionSwapUsecase(getSwap);
    });

    test('forwards the swap on success', () async {
      final swap = _swap();
      when(() => getSwap.execute('swap-1')).thenAnswer((_) async => swap);

      expect((await usecase.execute('swap-1') as Ok).value, swap);
    });

    test('sanitizes a thrown Boltz reason', () async {
      when(() => getSwap.execute('swap-1')).thenThrow(
        GetSwapException('boltz: swap not found for preimage abc123'),
      );

      final result = await usecase.execute('swap-1');

      final failure = (result as Err).failure as TransactionFailure;
      expect(failure, isA<TransactionSwapUnavailableFailure>());
      // A preimage is key material; a Boltz reason is developer detail.
      expect(failure.logMessage, isNot(contains('preimage')));
      expect(failure.logMessage, isNot(contains('boltz')));
    });
  });

  group('WatchTransactionSwapUsecase', () {
    late _MockWatchSwapUsecase watchSwap;
    late WatchTransactionSwapUsecase usecase;

    setUp(() {
      watchSwap = _MockWatchSwapUsecase();
      usecase = WatchTransactionSwapUsecase(watchSwap);
    });

    test('wraps each event in Ok', () async {
      final swap = _swap();
      when(
        () => watchSwap.execute('swap-1'),
      ).thenAnswer((_) => Stream.value(swap));

      final emitted = await usecase.execute('swap-1').toList();

      expect((emitted.single as Ok).value, swap);
    });

    test('turns a stream error into a failure value, not a throw', () async {
      when(() => watchSwap.execute('swap-1')).thenAnswer(
        (_) => Stream.error(StateError('boltz websocket closed: 1006')),
      );

      final emitted = await usecase.execute('swap-1').toList();

      final failure = (emitted.single as Err).failure as TransactionFailure;
      expect(failure, isA<TransactionSwapUnavailableFailure>());
      expect(failure.logMessage, isNot(contains('websocket')));
    });

    test('turns a throw on subscribe into a failure value', () async {
      when(
        () => watchSwap.execute('swap-1'),
      ).thenThrow(WatchSwapException('no such swap'));

      final emitted = await usecase.execute('swap-1').toList();

      expect(
        (emitted.single as Err).failure,
        isA<TransactionSwapUnavailableFailure>(),
      );
    });
  });
}
