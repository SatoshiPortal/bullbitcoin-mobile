import 'package:bull_swap/src/data/bull/exchange_models.dart';
import 'package:bull_swap/bull_swap.dart';
import 'package:drift/native.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

class _MockExchangeDatasource extends Mock
    implements ExchangePublicApiDatasource {}

OrderSwapModel _orderModel() => OrderSwapModel(
  orderId: 'order-1',
  orderNumber: 1,
  payinAmount: '0.00001010',
  payoutAmount: '0.00001000',
  payinCurrency: 'LBTC',
  payoutCurrency: 'BTCLN',
  payinMethod: 'Liquid',
  payoutMethod: 'Lightning',
  orderType: 'Swap',
  orderStatus: 'Awaiting payment',
  payinStatus: 'In progress',
  payoutStatus: 'In progress',
  messageCode: 'ORDER_CREATED',
  lightningInvoice: 'invoice',
  liquidAddress: 'liquid-payin',
  createdAt: DateTime.utc(2026, 8, 5, 12),
  confirmationDeadline: DateTime.utc(2026, 8, 5, 12, 5),
);

OrderSwap _boltzOrder(DateTime now) => OrderSwap(
  orderId: 'boltz-order-1',
  orderNumber: 0,
  inNetwork: OrderSwapNetwork.liquid,
  outNetwork: OrderSwapNetwork.lightning,
  payinAmountSat: BigInt.from(1010),
  payoutAmountSat: BigInt.from(1000),
  payinCurrency: 'L-BTC',
  payoutCurrency: 'LN-BTC',
  payinMethod: 'onchain',
  payoutMethod: 'lightning',
  orderType: 'swap',
  orderStatus: 'pending',
  payinStatus: 'pending',
  payoutStatus: 'pending',
  messageCode: 'OK',
  liquidAddress: 'lq-payin',
  lightningInvoice: 'invoice',
  createdAt: now,
  confirmationDeadline: now.add(const Duration(hours: 1)),
);

void main() {
  late SwapDatabase database;
  late _MockExchangeDatasource remote;
  late _MockExchangeDatasource mainnetRemote;
  final now = DateTime.utc(2026, 8, 5, 12);

  setUp(() {
    database = SwapDatabase.forTesting(NativeDatabase.memory());
    remote = _MockExchangeDatasource();
    mainnetRemote = _MockExchangeDatasource();
  });

  tearDown(() => database.close());

  test('stamps providerId "bull" on the exchange create path', () async {
    when(
      () => remote.createOrderSwap(
        requestId: 'request-1',
        amountSat: BigInt.from(1000),
        isInAmountFixed: false,
        inNetwork: OrderSwapNetwork.liquid,
        outNetwork: OrderSwapNetwork.lightning,
        destinationAddress: 'invoice',
        fallbackAddress: 'fallback',
      ),
    ).thenAnswer((_) async => _orderModel());

    final repository = OrderSwapRepositoryImpl(
      remote,
      mainnetRemote,
      OrderSwapLocalDatasource(database),
      now: () => now,
      newLocalId: () => 'local-1',
      newRequestId: () => 'request-1',
    );

    final result = await repository.createOrder(
      amountSat: BigInt.from(1000),
      isInAmountFixed: false,
      inNetwork: OrderSwapNetwork.liquid,
      outNetwork: OrderSwapNetwork.lightning,
      destinationAddress: 'invoice',
      fallbackAddress: 'fallback',
      purpose: OrderSwapPurpose.sendLightning,
      environment: OrderSwapEnvironment.testnet,
    );

    expect(result, isA<Ok<OrderSwapRecord, SwapFailure>>());
    final row = (await database.select(database.orderSwaps).get()).single;
    expect(row.providerId, 'bull');
  });

  test('stamps providerId "boltz" on the provider create path', () async {
    final repository = OrderSwapRepositoryImpl(
      remote,
      mainnetRemote,
      OrderSwapLocalDatasource(database),
      now: () => now,
      newLocalId: () => 'local-1',
      newRequestId: () => 'request-1',
      createViaProvider:
          ({
            required record,
            required amountSat,
            required isInAmountFixed,
            required inNetwork,
            required outNetwork,
            required destinationAddress,
            required fallbackAddress,
          }) async => _boltzOrder(now),
    );

    final result = await repository.createOrder(
      amountSat: BigInt.from(1000),
      isInAmountFixed: false,
      inNetwork: OrderSwapNetwork.liquid,
      outNetwork: OrderSwapNetwork.lightning,
      destinationAddress: 'invoice',
      fallbackAddress: 'fallback',
      purpose: OrderSwapPurpose.sendLightning,
      environment: OrderSwapEnvironment.testnet,
    );

    // The exchange datasource is left unstubbed: the provider create path must
    // never reach it (doing so would throw a missing-stub error).
    expect(result, isA<Ok<OrderSwapRecord, SwapFailure>>());
    final row = (await database.select(database.orderSwaps).get()).single;
    expect(row.providerId, 'boltz');
  });
}
