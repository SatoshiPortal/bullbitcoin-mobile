import 'package:bull_swap/bull_swap.dart';
import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

class _MockDio extends Mock implements Dio {}

Response<dynamic> _rpcResult(Map<String, dynamic> data, Object? result) =>
    Response<dynamic>(
      requestOptions: RequestOptions(path: ''),
      statusCode: 200,
      data: {'jsonrpc': '2.0', 'id': data['id'], 'result': result},
    );

void main() {
  late _MockDio dio;
  late BullSwapProvider provider;

  const config = SwapProviderConfig(
    id: 'bull',
    kind: SwapProviderKind.bull,
    name: 'Bull Bitcoin',
    isBuiltIn: true,
  );

  setUp(() {
    dio = _MockDio();
    final ds = ExchangePublicApiDatasource(dio);
    provider = BullSwapProvider(ds, ds, config: config);
  });

  void stub(Object? Function(String method, Map<String, dynamic> data) build) {
    when(
      () => dio.post<dynamic>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((invocation) async {
      final data = invocation.namedArguments[#data] as Map<String, dynamic>;
      return _rpcResult(data, build(data['method'] as String, data));
    });
  }

  test('quote maps exchange amounts into a SwapQuote', () async {
    stub(
      (method, data) => {
        'inAmount': '0.001',
        'outAmount': '0.00098',
        'inPaymentProcessorCurrencyCode': 'BTC',
        'outPaymentProcessorCurrencyCode': 'LBTC',
        'orderFees': [
          {'percent': '0.1'},
        ],
        'warning': <String>[],
      },
    );

    final result = await provider.quote(
      inNetwork: SwapNetwork.bitcoin,
      outNetwork: SwapNetwork.liquid,
      amountSat: BigInt.from(100000),
      isInAmountFixed: true,
      environment: SwapEnvironment.mainnet,
    );

    expect(result, isA<Ok<SwapQuote, SwapFailure>>());
    final quote = (result as Ok).value;
    expect(quote.payinAmountSat, BigInt.from(100000));
    expect(quote.payoutAmountSat, BigInt.from(98000));
    expect(quote.feesSat, BigInt.from(2000));
    expect(quote.providerId, 'bull');
  });

  test('createChainSwap maps an order into a CreatedSwap', () async {
    stub(
      (method, data) => {
        'orderId': 'ord-1',
        'orderNumber': 42,
        'payinAmount': '0.001',
        'payoutAmount': '0.00098',
        'payinCurrency': 'BTC',
        'payoutCurrency': 'LBTC',
        'payinMethod': 'onchain',
        'payoutMethod': 'onchain',
        'orderType': 'swap',
        'orderStatus': 'pending',
        'payinStatus': 'pending',
        'payoutStatus': 'pending',
        'message': {'code': 'OK'},
        'bitcoinAddress': 'bc1qpayin',
        'createdAt': '2026-08-28T00:00:00Z',
        'confirmationDeadline': '2026-08-28T01:00:00Z',
      },
    );

    final result = await provider.createChainSwap(
      fromNetwork: SwapNetwork.bitcoin,
      toNetwork: SwapNetwork.liquid,
      amountSat: BigInt.from(100000),
      isInAmountFixed: true,
      payoutAddress: 'lq1payout',
      refundAddress: 'bc1refund',
      environment: SwapEnvironment.mainnet,
    );

    final swap = (result as Ok).value;
    expect(swap.swapId, 'ord-1');
    expect(swap.payinAddress, 'bc1qpayin');
    expect(swap.payinAmountSat, BigInt.from(100000));
  });

  test('maps HTTP 418 to SwapProviderUnavailableFailure', () async {
    when(
      () => dio.post<dynamic>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (invocation) async => Response<dynamic>(
        requestOptions: RequestOptions(path: ''),
        statusCode: 418,
        data: const <String, dynamic>{},
      ),
    );

    final result = await provider.quote(
      inNetwork: SwapNetwork.bitcoin,
      outNetwork: SwapNetwork.liquid,
      amountSat: BigInt.from(100000),
      isInAmountFixed: true,
      environment: SwapEnvironment.mainnet,
    );

    expect((result as Err).failure, isA<SwapProviderUnavailableFailure>());
  });
}
