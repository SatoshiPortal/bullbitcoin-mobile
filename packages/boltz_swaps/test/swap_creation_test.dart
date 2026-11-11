import 'package:boltz_swaps/boltz_swaps.dart';
import 'package:boltz_swaps/src/util.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

class _MockSwapRepository extends Mock implements SwapRepository {}

class _MockChainSwap extends Mock implements ChainSwap {}

class _MockLnSendSwap extends Mock implements LnSendSwap {}

class _MockLnReceiveSwap extends Mock implements LnReceiveSwap {}

BoltzApiException _status(String status) => BoltzApiException(
  kind: 'HTTPStatusNotSuccess',
  message: 'HTTP Status Not Success: $status, {"error":"x"}',
);

void main() {
  group('BoltzApiException', () {
    test('reads the status code Boltz answered with', () {
      expect(_status("418 I'm a teapot").statusCode, 418);
      expect(_status('503 Service Unavailable').statusCode, 503);
    });

    test('treats no answer, server errors and 418 as unreachable', () {
      expect(
        BoltzApiException(
          kind: 'HTTP',
          message: 'error sending request',
        ).isUnreachable,
        isTrue,
      );
      expect(_status('502 Bad Gateway').isUnreachable, isTrue);
      expect(_status("418 I'm a teapot").isUnreachable, isTrue);
      expect(_status('400 Bad Request').isUnreachable, isFalse);
      expect(
        BoltzApiException(kind: 'Generic', message: 'x').isUnreachable,
        isFalse,
      );
    });

    test('classifies into the creation failures', () {
      expect(
        classifySwapCreationFailure(_status("418 I'm a teapot")),
        isA<SwapsBoltzUnavailableFailure>(),
      );
      expect(
        classifySwapCreationFailure(_status('400 Bad Request')),
        isA<SwapsBoltzRejectedFailure>(),
      );
      expect(
        classifySwapCreationFailure(
          SwapsException('no default bitcoin wallet seed'),
        ),
        isA<SwapsMasterKeyUnavailableFailure>(),
      );
    });
  });

  late _MockSwapRepository repository;

  setUpAll(() => registerFallbackValue(SwapType.bitcoinToLiquid));

  setUp(() {
    repository = _MockSwapRepository();
    when(
      () => repository.limits(any()),
    ).thenAnswer((_) async => const SwapLimits(min: 25000, max: 1000000));
  });

  group('CreateChainSwapUsecase', () {
    late CreateChainSwapUsecase usecase;

    setUp(() => usecase = CreateChainSwapUsecase(swapRepository: repository));

    test('refuses an amount outside the limits without creating', () async {
      final result = await usecase.execute(
        sendWalletId: 'w',
        amountSat: 1000,
        fromLiquid: false,
      );

      final failure = (result as Err).failure as SwapsAmountOutOfLimitsFailure;
      expect(failure.minSat, 25000);
      expect(failure.isBelowMinimum(1000), isTrue);
      verify(() => repository.limits(SwapType.bitcoinToLiquid)).called(1);
      verifyNever(
        () => repository.createChain(
          sendWalletId: any(named: 'sendWalletId'),
          amountSat: any(named: 'amountSat'),
          fromLiquid: any(named: 'fromLiquid'),
        ),
      );
    });

    test('creates the swap inside the limits', () async {
      final swap = _MockChainSwap();
      when(
        () => repository.createChain(
          sendWalletId: 'w',
          amountSat: 50000,
          fromLiquid: true,
          receiveWalletId: 'r',
        ),
      ).thenAnswer((_) async => swap);

      final result = await usecase.execute(
        sendWalletId: 'w',
        amountSat: 50000,
        fromLiquid: true,
        receiveWalletId: 'r',
      );

      expect((result as Ok).value, same(swap));
      verify(() => repository.limits(SwapType.liquidToBitcoin)).called(1);
    });

    test('reports Boltz unavailable when the limits cannot load', () async {
      when(
        () => repository.limits(any()),
      ).thenThrow(BoltzApiException(kind: 'HTTP', message: 'timed out'));

      final result = await usecase.execute(
        sendWalletId: 'w',
        amountSat: 50000,
        fromLiquid: false,
      );

      expect((result as Err).failure, isA<SwapsBoltzUnavailableFailure>());
    });
  });

  group('CreateLightningSendSwapUsecase', () {
    late CreateLightningSendSwapUsecase usecase;

    setUp(
      () =>
          usecase = CreateLightningSendSwapUsecase(swapRepository: repository),
    );

    test('checks the invoice amount against the submarine limits', () async {
      final result = await usecase.execute(
        walletId: 'w',
        invoice: 'lnbc1',
        invoiceAmountSat: 2000000,
        fromLiquid: true,
      );

      expect((result as Err).failure, isA<SwapsAmountOutOfLimitsFailure>());
      verify(() => repository.limits(SwapType.liquidToLightning)).called(1);
    });

    test('reports a Boltz refusal as rejected', () async {
      when(
        () => repository.createLightningSend(
          walletId: 'w',
          invoice: 'lnbc1',
          fromLiquid: false,
        ),
      ).thenThrow(_status('400 Bad Request'));

      final result = await usecase.execute(
        walletId: 'w',
        invoice: 'lnbc1',
        invoiceAmountSat: 50000,
        fromLiquid: false,
      );

      expect((result as Err).failure, isA<SwapsBoltzRejectedFailure>());
    });

    test('creates the swap inside the limits', () async {
      final swap = _MockLnSendSwap();
      when(
        () => repository.createLightningSend(
          walletId: 'w',
          invoice: 'lnbc1',
          fromLiquid: false,
        ),
      ).thenAnswer((_) async => swap);

      final result = await usecase.execute(
        walletId: 'w',
        invoice: 'lnbc1',
        invoiceAmountSat: 50000,
        fromLiquid: false,
      );

      expect((result as Ok).value, same(swap));
      verify(() => repository.limits(SwapType.bitcoinToLightning)).called(1);
    });
  });

  group('CreateLightningReceiveSwapUsecase', () {
    late CreateLightningReceiveSwapUsecase usecase;

    setUp(
      () => usecase = CreateLightningReceiveSwapUsecase(
        swapRepository: repository,
      ),
    );

    test('creates the swap inside the reverse limits', () async {
      final swap = _MockLnReceiveSwap();
      when(
        () => repository.createLightningReceive(
          walletId: 'w',
          amountSat: 50000,
          toLiquid: true,
          description: 'coffee',
        ),
      ).thenAnswer((_) async => swap);

      final result = await usecase.execute(
        walletId: 'w',
        amountSat: 50000,
        toLiquid: true,
        description: 'coffee',
      );

      expect((result as Ok).value, same(swap));
      verify(() => repository.limits(SwapType.lightningToLiquid)).called(1);
    });

    test('reports a 418 as Boltz unavailable', () async {
      when(
        () => repository.createLightningReceive(
          walletId: 'w',
          amountSat: 50000,
          toLiquid: false,
        ),
      ).thenThrow(_status("418 I'm a teapot"));

      final result = await usecase.execute(
        walletId: 'w',
        amountSat: 50000,
        toLiquid: false,
      );

      expect((result as Err).failure, isA<SwapsBoltzUnavailableFailure>());
      verify(() => repository.limits(SwapType.lightningToBitcoin)).called(1);
    });
  });
}
