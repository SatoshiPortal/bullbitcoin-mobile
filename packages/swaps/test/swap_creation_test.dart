import 'package:swaps/swaps.dart';
import 'package:swaps/src/util.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

class _MockBoltzSwaps extends Mock implements BoltzSwaps {}

class _MockSwapResolver extends Mock implements SwapResolver {}

class _MockSwapStore extends Mock implements SwapStore {}

class _MockChainSwap extends Mock implements ChainSwap {}

class _MockLnSendSwap extends Mock implements LnSendSwap {}

class _MockLnReceiveSwap extends Mock implements LnReceiveSwap {}

class _MockSwapWatcher extends Mock implements SwapWatcher {}

BoltzApiException _status(String status) => BoltzApiException(
  kind: 'HTTPStatusNotSuccess',
  message: 'HTTP Status Not Success: $status, {"error":"x"}',
);

RestoredSwap _restored(String id, {bool recoverable = true}) => RestoredSwap(
  id: id,
  kind: RestoredSwapKind.crossChain,
  status: SwapStatus.refundable,
  recoverable: recoverable,
  amountSat: 100000,
  createdAt: DateTime(2026, 7),
  fromAsset: 'L-BTC',
  toAsset: 'BTC',
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
      expect(
        classifySwapCreationFailure(
          const SwapsAmountOutOfLimitsException(minSat: 25000, maxSat: 1000000),
        ),
        isA<SwapsAmountOutOfLimitsFailure>(),
      );
    });
  });

  late _MockBoltzSwaps boltz;
  late _MockSwapResolver resolver;
  late _MockSwapStore store;
  late _MockSwapWatcher watcher;

  setUpAll(() {
    registerFallbackValue(_MockChainSwap() as Swap);
    registerFallbackValue(_restored('fallback'));
  });

  setUp(() {
    boltz = _MockBoltzSwaps();
    resolver = _MockSwapResolver();
    store = _MockSwapStore();
    watcher = _MockSwapWatcher();
    when(() => watcher.processSwap(any())).thenAnswer((_) async {});
  });

  group('chain swap creation', () {
    test(
      'creates Liquid to Bitcoin into a wallet and starts watching',
      () async {
        final swap = _MockChainSwap();
        when(
          () => boltz.createLiquidToBitcoinSwap(
            sendWalletId: 'w-liquid',
            amountSat: 50000,
            destination: const ToWallet('w-btc'),
          ),
        ).thenAnswer((_) async => Ok(swap));

        final result = await CreateLiquidToBitcoinSwapUsecase(boltz, watcher)
            .execute(
              sendWalletId: 'w-liquid',
              amountSat: 50000,
              destination: const ToWallet('w-btc'),
            );

        expect((result as Ok).value, same(swap));
        verify(() => watcher.ensureRunning()).called(1);
      },
    );

    test('creates Bitcoin to Liquid to an address', () async {
      final swap = _MockChainSwap();
      when(
        () => boltz.createBitcoinToLiquidSwap(
          sendWalletId: 'w-btc',
          amountSat: 50000,
          destination: const ToAddress('lq1external'),
        ),
      ).thenAnswer((_) async => Ok(swap));

      final result = await CreateBitcoinToLiquidSwapUsecase(boltz, watcher)
          .execute(
            sendWalletId: 'w-btc',
            amountSat: 50000,
            destination: const ToAddress('lq1external'),
          );

      expect((result as Ok).value, same(swap));
    });

    test('a refused creation is returned and watches nothing', () async {
      when(
        () => boltz.createBitcoinToLiquidSwap(
          sendWalletId: 'w-btc',
          amountSat: 1000,
          destination: const ToWallet('w-liquid'),
        ),
      ).thenAnswer(
        (_) async => const Err(
          SwapsAmountOutOfLimitsFailure(minSat: 25000, maxSat: 1000000),
        ),
      );

      final result = await CreateBitcoinToLiquidSwapUsecase(boltz, watcher)
          .execute(
            sendWalletId: 'w-btc',
            amountSat: 1000,
            destination: const ToWallet('w-liquid'),
          );

      expect((result as Err).failure, isA<SwapsAmountOutOfLimitsFailure>());
      verifyNever(() => watcher.ensureRunning());
    });
  });

  group('lightning swap creation', () {
    test('pays an invoice from Liquid through the Liquid pair', () async {
      final swap = _MockLnSendSwap();
      when(
        () => boltz.createLiquidToLightningSwap(
          walletId: 'w-liquid',
          invoice: 'lnbc1',
        ),
      ).thenAnswer((_) async => Ok(swap));

      final result = await CreateLiquidToLightningSwapUsecase(
        boltz,
        watcher,
      ).execute(walletId: 'w-liquid', invoice: 'lnbc1');

      expect((result as Ok).value, same(swap));
      verify(() => watcher.ensureRunning()).called(1);
    });

    test('a Boltz refusal is returned as rejected', () async {
      when(
        () => boltz.createBitcoinToLightningSwap(
          walletId: 'w-btc',
          invoice: 'lnbc1',
        ),
      ).thenAnswer((_) async => const Err(SwapsBoltzRejectedFailure()));

      final result = await CreateBitcoinToLightningSwapUsecase(
        boltz,
        watcher,
      ).execute(walletId: 'w-btc', invoice: 'lnbc1');

      expect((result as Err).failure, isA<SwapsBoltzRejectedFailure>());
      verifyNever(() => watcher.ensureRunning());
    });

    test('receives into Liquid through the Liquid reverse pair', () async {
      final swap = _MockLnReceiveSwap();
      when(
        () => boltz.createLightningToLiquidSwap(
          walletId: 'w-liquid',
          amountSat: 50000,
          description: 'coffee',
        ),
      ).thenAnswer((_) async => Ok(swap));

      final result = await CreateLightningToLiquidSwapUsecase(
        boltz,
        watcher,
      ).execute(walletId: 'w-liquid', amountSat: 50000, description: 'coffee');

      expect((result as Ok).value, same(swap));
    });

    test('receives into Bitcoin through the Bitcoin reverse pair', () async {
      when(
        () => boltz.createLightningToBitcoinSwap(
          walletId: 'w-btc',
          amountSat: 50000,
        ),
      ).thenAnswer((_) async => const Err(SwapsBoltzUnavailableFailure()));

      final result = await CreateLightningToBitcoinSwapUsecase(
        boltz,
        watcher,
      ).execute(walletId: 'w-btc', amountSat: 50000);

      expect((result as Err).failure, isA<SwapsBoltzUnavailableFailure>());
    });
  });

  group('GetSwapLimitsAndFeesUsecase', () {
    test('returns the provider\'s answer', () async {
      when(
        () => boltz.limitsAndFees(SwapType.bitcoinToLiquid),
      ).thenAnswer((_) async => const Err(SwapsBoltzUnavailableFailure()));

      final result = await GetSwapLimitsAndFeesUsecase(
        boltz,
      ).execute(SwapType.bitcoinToLiquid);

      expect((result as Err).failure, isA<SwapsBoltzUnavailableFailure>());
    });
  });

  group('RecordSwapLockupUsecase', () {
    test('records the lockup and hands the swap to the watcher', () async {
      final swap = _MockChainSwap();
      when(
        () =>
            resolver.recordLockup(swapId: 's1', txid: 'tx', lockupFeeSat: 300),
      ).thenAnswer((_) async => Ok(swap));

      final result = await RecordSwapLockupUsecase(
        resolver,
        watcher,
      ).execute(swapId: 's1', txid: 'tx', lockupFeeSat: 300);

      expect((result as Ok).value, same(swap));
      verify(() => watcher.ensureRunning()).called(1);
      verify(() => watcher.processSwap(swap)).called(1);
    });

    test('reports a failure when the lockup cannot be recorded', () async {
      when(
        () => resolver.recordLockup(swapId: 's1', txid: 'tx'),
      ).thenAnswer((_) async => const Err(SwapsUnexpectedFailure('locked')));

      final result = await RecordSwapLockupUsecase(
        resolver,
        watcher,
      ).execute(swapId: 's1', txid: 'tx');

      expect(result, isA<Err>());
      verifyNever(() => watcher.processSwap(any()));
    });
  });

  group('RestoreSwapsUsecase', () {
    test('offers what is missing here or stored but unresolved', () async {
      final stuck = Swap.chain(
        id: 'stuck',
        keyIndex: 0,
        type: SwapType.liquidToBitcoin,
        status: SwapStatus.completed,
        environment: Environment.mainnet,
        creationTime: DateTime(2026, 7),
        sendWalletId: 'w-liquid',
        paymentAddress: 'lq1lockup',
        paymentAmount: 100000,
        sendTxid: 'lockup-txid',
      );
      when(
        () => resolver.restore(),
      ).thenAnswer((_) async => Ok([_restored('missing'), _restored('stuck')]));
      when(() => store.all()).thenAnswer((_) async => Ok([stuck]));

      final result = await RestoreSwapsUsecase(resolver, store).execute();

      final restorable =
          (result as Ok<List<RestorableSwap>, SwapsFailure>).value;
      expect(restorable.map((r) => r.swap.id), ['missing', 'stuck']);
      expect(restorable.map((r) => r.existsLocally), [false, true]);
      expect(restorable.every((r) => r.isRescuable), isTrue);
    });

    test('a provider failure is returned', () async {
      when(
        () => resolver.restore(),
      ).thenAnswer((_) async => const Err(SwapsBoltzUnavailableFailure()));

      final result = await RestoreSwapsUsecase(resolver, store).execute();

      expect((result as Err).failure, isA<SwapsBoltzUnavailableFailure>());
      verifyNever(() => store.all());
    });
  });

  group('RescueSwapUsecase', () {
    test('drives the rescued swap and returns its stored row', () async {
      final rescued = _MockChainSwap();
      final stored = _MockChainSwap();
      when(() => rescued.id).thenReturn('r1');
      final restored = _restored('r1');
      when(
        () => resolver.rescue(restored, walletId: 'w-liquid'),
      ).thenAnswer((_) async => Ok(rescued));
      when(() => store.get('r1')).thenAnswer((_) async => Ok(stored));

      final result = await RescueSwapUsecase(
        resolver,
        store,
        watcher,
      ).execute(restored: restored, selectedWalletId: 'w-liquid');

      expect((result as Ok).value, same(stored));
      verify(() => watcher.ensureRunning()).called(1);
      verify(() => watcher.processSwap(rescued)).called(1);
    });

    test('a refused rescue drives nothing', () async {
      final restored = _restored('r1');
      when(
        () => resolver.rescue(restored, walletId: 'w-btc'),
      ).thenAnswer((_) async => const Err(SwapsUnexpectedFailure('side')));

      final result = await RescueSwapUsecase(
        resolver,
        store,
        watcher,
      ).execute(restored: restored, selectedWalletId: 'w-btc');

      expect(result, isA<Err>());
      verifyNever(() => watcher.processSwap(any()));
    });
  });
}
