import 'package:bull_swap/src/data/bull/exchange_models.dart';
import 'package:bull_swap/bull_swap.dart';
import 'package:drift/native.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

class _MockExchangeDatasource extends Mock
    implements ExchangePublicApiDatasource {}

OrderSwapQuote _boltzQuote() => OrderSwapQuote(
  inAmountSat: BigInt.from(100000),
  outAmountSat: BigInt.from(99000),
  inNetwork: OrderSwapNetwork.bitcoin,
  outNetwork: OrderSwapNetwork.lightning,
  inCurrency: 'BTC',
  outCurrency: 'LN-BTC',
  feeBasisPoints: 100,
  warnings: const [],
);

void main() {
  late SwapDatabase database;
  late _MockExchangeDatasource remote;
  late _MockExchangeDatasource mainnetRemote;

  setUp(() {
    database = SwapDatabase.forTesting(NativeDatabase.memory());
    remote = _MockExchangeDatasource();
    mainnetRemote = _MockExchangeDatasource();
  });

  tearDown(() => database.close());

  OrderSwapRepositoryImpl build({
    required Future<OrderSwapQuote?> Function({
      required OrderSwapEnvironment environment,
      required BigInt amountSat,
      required bool isInAmountFixed,
      required OrderSwapNetwork inNetwork,
      required OrderSwapNetwork outNetwork,
    })
    quoteViaProvider,
  }) => OrderSwapRepositoryImpl(
    remote,
    mainnetRemote,
    OrderSwapLocalDatasource(database),
    quoteViaProvider: quoteViaProvider,
  );

  test(
    'routes the quote through the provider hook and skips the exchange',
    () async {
      final repository = build(
        quoteViaProvider:
            ({
              required environment,
              required amountSat,
              required isInAmountFixed,
              required inNetwork,
              required outNetwork,
            }) async => _boltzQuote(),
      );

      final result = await repository.getQuote(
        environment: OrderSwapEnvironment.mainnet,
        amountSat: BigInt.from(100000),
        isInAmountFixed: true,
        inNetwork: OrderSwapNetwork.bitcoin,
        outNetwork: OrderSwapNetwork.lightning,
      );

      // The exchange datasource is left unstubbed: reaching it would throw a
      // missing-stub error, so an Ok with the provider's payout proves the quote
      // came from the hook, not the exchange RPC.
      expect(result, isA<Ok<OrderSwapQuote, SwapFailure>>());
      expect(
        (result as Ok<OrderSwapQuote, SwapFailure>).value.outAmountSat,
        BigInt.from(99000),
      );
    },
  );

  test('falls back to the exchange RPC when the hook returns null', () async {
    when(
      () => mainnetRemote.getBestSwapOption(
        amountSat: BigInt.from(100000),
        isInAmountFixed: true,
        inNetwork: OrderSwapNetwork.bitcoin,
        outNetwork: OrderSwapNetwork.liquid,
      ),
    ).thenAnswer(
      (_) async => const OrderSwapQuoteModel(
        inAmount: '0.00001010',
        outAmount: '0.00001000',
        inCurrency: 'BTC',
        outCurrency: 'LBTC',
        feePercents: ['1'],
        warnings: [],
      ),
    );

    final repository = build(
      quoteViaProvider:
          ({
            required environment,
            required amountSat,
            required isInAmountFixed,
            required inNetwork,
            required outNetwork,
          }) async => null,
    );

    final result = await repository.getQuote(
      environment: OrderSwapEnvironment.mainnet,
      amountSat: BigInt.from(100000),
      isInAmountFixed: true,
      inNetwork: OrderSwapNetwork.bitcoin,
      outNetwork: OrderSwapNetwork.liquid,
    );

    expect(result, isA<Ok<OrderSwapQuote, SwapFailure>>());
    verify(
      () => mainnetRemote.getBestSwapOption(
        amountSat: BigInt.from(100000),
        isInAmountFixed: true,
        inNetwork: OrderSwapNetwork.bitcoin,
        outNetwork: OrderSwapNetwork.liquid,
      ),
    ).called(1);
  });

  test('surfaces a typed failure thrown by the provider hook', () async {
    final repository = build(
      quoteViaProvider:
          ({
            required environment,
            required amountSat,
            required isInAmountFixed,
            required inNetwork,
            required outNetwork,
          }) async => throw const SwapNetworkFailure('boltz down'),
    );

    final result = await repository.getQuote(
      environment: OrderSwapEnvironment.mainnet,
      amountSat: BigInt.from(100000),
      isInAmountFixed: true,
      inNetwork: OrderSwapNetwork.bitcoin,
      outNetwork: OrderSwapNetwork.lightning,
    );

    final failure = (result as Err<OrderSwapQuote, SwapFailure>).failure;
    expect(failure, isA<SwapNetworkFailure>());
  });
}
