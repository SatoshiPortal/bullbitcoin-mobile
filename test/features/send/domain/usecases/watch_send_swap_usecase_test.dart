import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/watch_send_swap_usecase.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSwapFacade extends Mock implements SwapFacade {}

void main() {
  late _MockSwapFacade facade;
  late WatchSendSwapUsecase usecase;

  setUp(() {
    facade = _MockSwapFacade();
    usecase = WatchSendSwapUsecase(facade);
  });

  test('forwards an order update untouched', () async {
    final record = _record();
    when(
      () => facade.watchOrder('local-1'),
    ).thenAnswer((_) => Stream.value(Ok<OrderSwapRecord, SwapFailure>(record)));

    final first = await usecase.execute('local-1').first;

    expect(first, isA<Ok<OrderSwapRecord, SendFailure>>());
    expect((first as Ok<OrderSwapRecord, SendFailure>).value, record);
  });

  test('no swap failure escapes as a swap type', () async {
    // The whole point of the boundary: a consumer of this stream must never
    // have to know SwapFailure exists.
    final swapFailures = <SwapFailure>[
      const SwapOrderExpiredFailure('expired'),
      const SwapProviderFailure('boltz 502'),
      const SwapNetworkFailure('timeout'),
      const SwapStorageFailure('db locked'),
      const SwapValidationFailure(logMessage: 'bad invoice'),
      const SwapOrderNotFoundFailure('gone'),
      const SwapUnexpectedFailure('boom'),
    ];
    when(() => facade.watchOrder('local-1')).thenAnswer(
      (_) => Stream.fromIterable(
        swapFailures.map(Err<OrderSwapRecord, SwapFailure>.new),
      ),
    );

    final results = await usecase.execute('local-1').toList();

    expect(results, hasLength(swapFailures.length));
    for (final result in results) {
      switch (result) {
        case Ok():
          fail('a swap failure must not surface as a successful update');
        case Err(:final failure):
          expect(failure, isA<SendFailure>());
          expect(failure, isNot(isA<SwapFailure>()));
      }
    }
  });

  test('maps an out-of-bounds amount to the send equivalent', () async {
    when(() => facade.watchOrder('local-1')).thenAnswer(
      (_) => Stream.value(
        Err<OrderSwapRecord, SwapFailure>(
          SwapAmountOutOfBoundsFailure(
            limitAmountSat: BigInt.from(1000),
            isMinimum: true,
            logMessage: 'below the boltz minimum',
          ),
        ),
      ),
    );

    final first = await usecase.execute('local-1').first;

    final failure = (first as Err<OrderSwapRecord, SendFailure>).failure;
    expect(failure, isA<SendAmountOutOfBoundsFailure>());
    expect(
      (failure as SendAmountOutOfBoundsFailure).minimumSat,
      BigInt.from(1000),
    );
    expect(failure.maximumSat, isNull);
  });

  test('a failed update does not end the stream', () async {
    final record = _record();
    when(() => facade.watchOrder('local-1')).thenAnswer(
      (_) => Stream.fromIterable([
        const Err<OrderSwapRecord, SwapFailure>(SwapNetworkFailure('blip')),
        Ok<OrderSwapRecord, SwapFailure>(record),
      ]),
    );

    final results = await usecase.execute('local-1').toList();

    expect(results, hasLength(2));
    expect(results.last, isA<Ok<OrderSwapRecord, SendFailure>>());
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
