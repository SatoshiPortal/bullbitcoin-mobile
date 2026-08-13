import 'dart:async';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/swap/data/datasources/exchange_public_api_datasource.dart';
import 'package:bb_mobile/features/swap/data/datasources/order_swap_local_datasource.dart';
import 'package:bb_mobile/features/swap/data/models/order_swap_model.dart';
import 'package:bb_mobile/features/swap/data/models/order_swap_quote_model.dart';
import 'package:bb_mobile/features/swap/data/order_swap_repository_impl.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_network.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_quote.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_record.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockExchangeDatasource extends Mock
    implements ExchangePublicApiDatasource {}

void main() {
  late SqliteDatabase database;
  late _MockExchangeDatasource remote;
  late _MockExchangeDatasource mainnetRemote;
  late OrderSwapRepositoryImpl repository;
  var now = DateTime.utc(2026, 8, 5, 12);

  setUp(() {
    now = DateTime.utc(2026, 8, 5, 12);
    database = SqliteDatabase(NativeDatabase.memory());
    remote = _MockExchangeDatasource();
    mainnetRemote = _MockExchangeDatasource();
    repository = OrderSwapRepositoryImpl(
      remote,
      mainnetRemote,
      OrderSwapLocalDatasource(database),
      now: () => now,
      newLocalId: () => 'local-1',
      newRequestId: () => 'request-1',
    );
  });

  tearDown(() => database.close());

  test('preserves the measured minimum amount rejection', () async {
    when(
      () => remote.getBestSwapOption(
        amountSat: BigInt.from(50000),
        isInAmountFixed: false,
        inNetwork: OrderSwapNetwork.liquid,
        outNetwork: OrderSwapNetwork.bitcoin,
      ),
    ).thenThrow(
      const ExchangeRpcException(
        apiCode: 'ERR_ORD_LMT001',
        limit: '0.00100000',
        limitOperator: 'greater than or equal',
      ),
    );

    final result = await repository.getQuote(
      environment: OrderSwapEnvironment.testnet,
      amountSat: BigInt.from(50000),
      isInAmountFixed: false,
      inNetwork: OrderSwapNetwork.liquid,
      outNetwork: OrderSwapNetwork.bitcoin,
    );

    final failure = (result as Err<OrderSwapQuote, SwapFailure>).failure;
    expect(failure, isA<SwapAmountOutOfBoundsFailure>());
    expect(
      (failure as SwapAmountOutOfBoundsFailure).limitAmountSat,
      BigInt.from(100000),
    );
    expect(failure.isMinimum, isTrue);
  });

  test('routes mainnet quotes to the mainnet datasource', () async {
    when(
      () => mainnetRemote.getBestSwapOption(
        amountSat: BigInt.from(1000),
        isInAmountFixed: false,
        inNetwork: OrderSwapNetwork.bitcoin,
        outNetwork: OrderSwapNetwork.liquid,
      ),
    ).thenAnswer((_) async => _quoteModel());

    final result = await repository.getQuote(
      environment: OrderSwapEnvironment.mainnet,
      amountSat: BigInt.from(1000),
      isInAmountFixed: false,
      inNetwork: OrderSwapNetwork.bitcoin,
      outNetwork: OrderSwapNetwork.liquid,
    );

    expect(result, isA<Ok<OrderSwapQuote, SwapFailure>>());
    verifyNever(
      () => remote.getBestSwapOption(
        amountSat: BigInt.from(1000),
        isInAmountFixed: false,
        inNetwork: OrderSwapNetwork.bitcoin,
        outNetwork: OrderSwapNetwork.liquid,
      ),
    );
  });

  test('publishes the app update signal after HTTP 418', () async {
    when(
      () => remote.getBestSwapOption(
        amountSat: BigInt.from(1000),
        isInAmountFixed: false,
        inNetwork: OrderSwapNetwork.bitcoin,
        outNetwork: OrderSwapNetwork.liquid,
      ),
    ).thenThrow(const ExchangeAppUpdateRequiredException());
    final signal = expectLater(
      repository.watchAppUpdateRequired(),
      emits(true),
    );

    final result = await repository.getQuote(
      environment: OrderSwapEnvironment.testnet,
      amountSat: BigInt.from(1000),
      isInAmountFixed: false,
      inNetwork: OrderSwapNetwork.bitcoin,
      outNetwork: OrderSwapNetwork.liquid,
    );

    expect(result, isA<Err<OrderSwapQuote, SwapFailure>>());
    expect(repository.isAppUpdateRequired, isTrue);
    await signal;
  });

  test('does not preserve a false unknown order after HTTP 418', () async {
    when(
      () => remote.createOrderSwap(
        requestId: 'request-1',
        amountSat: BigInt.from(1000),
        isInAmountFixed: true,
        inNetwork: OrderSwapNetwork.liquid,
        outNetwork: OrderSwapNetwork.bitcoin,
        destinationAddress: 'tb1destination',
        fallbackAddress: 'tlq1fallback',
      ),
    ).thenThrow(const ExchangeAppUpdateRequiredException());

    final result = await repository.createOrder(
      amountSat: BigInt.from(1000),
      isInAmountFixed: true,
      inNetwork: OrderSwapNetwork.liquid,
      outNetwork: OrderSwapNetwork.bitcoin,
      destinationAddress: 'tb1destination',
      fallbackAddress: 'tlq1fallback',
      purpose: OrderSwapPurpose.transfer,
      environment: OrderSwapEnvironment.testnet,
    );

    expect(result, isA<Err<OrderSwapRecord, SwapFailure>>());
    expect(await database.select(database.orderSwaps).get(), isEmpty);
  });

  test('routes mainnet order creation and refresh to mainnet', () async {
    when(
      () => mainnetRemote.createOrderSwap(
        requestId: 'request-1',
        amountSat: BigInt.from(1000),
        isInAmountFixed: false,
        inNetwork: OrderSwapNetwork.liquid,
        outNetwork: OrderSwapNetwork.lightning,
        destinationAddress: 'invoice',
        fallbackAddress: 'fallback',
      ),
    ).thenAnswer((_) async => _orderModel());
    when(
      () => mainnetRemote.getOrderSwapSummary('order-1'),
    ).thenAnswer((_) async => _orderModel());

    final created = await repository.createOrder(
      amountSat: BigInt.from(1000),
      isInAmountFixed: false,
      inNetwork: OrderSwapNetwork.liquid,
      outNetwork: OrderSwapNetwork.lightning,
      destinationAddress: 'invoice',
      fallbackAddress: 'fallback',
      purpose: OrderSwapPurpose.sendLightning,
      environment: OrderSwapEnvironment.mainnet,
      sourceWalletId: 'wallet-1',
    );
    final refreshed = await repository.refreshOrder('local-1');

    expect(created, isA<Ok<OrderSwapRecord, SwapFailure>>());
    expect(refreshed, isA<Ok<OrderSwapRecord, SwapFailure>>());
    verify(() => mainnetRemote.getOrderSwapSummary('order-1')).called(1);
    verifyNever(() => remote.getOrderSwapSummary(any()));
  });

  test('allows internal Liquid to Bitcoin', () async {
    when(
      () => remote.createOrderSwap(
        requestId: 'request-1',
        amountSat: BigInt.from(1000),
        isInAmountFixed: true,
        inNetwork: OrderSwapNetwork.liquid,
        outNetwork: OrderSwapNetwork.bitcoin,
        destinationAddress: 'tb1destination',
        fallbackAddress: 'tlq1fallback',
      ),
    ).thenAnswer((_) async => _liquidToBitcoinOrderModel());

    final result = await repository.createOrder(
      amountSat: BigInt.from(1000),
      isInAmountFixed: true,
      inNetwork: OrderSwapNetwork.liquid,
      outNetwork: OrderSwapNetwork.bitcoin,
      destinationAddress: 'tb1destination',
      fallbackAddress: 'tlq1fallback',
      purpose: OrderSwapPurpose.transfer,
      environment: OrderSwapEnvironment.testnet,
      sourceWalletId: 'liquid-wallet',
      destinationWalletId: 'bitcoin-wallet',
    );

    expect(result, isA<Ok<OrderSwapRecord, SwapFailure>>());
  });

  test('accepts the live Lightning to Liquid response shape', () async {
    when(
      () => remote.createOrderSwap(
        requestId: 'request-1',
        amountSat: BigInt.from(10000),
        isInAmountFixed: true,
        inNetwork: OrderSwapNetwork.lightning,
        outNetwork: OrderSwapNetwork.liquid,
        destinationAddress: 'tlq1destination',
        fallbackAddress: null,
      ),
    ).thenAnswer((_) async => _receiveOrderModel());

    final result = await repository.createOrder(
      amountSat: BigInt.from(10000),
      isInAmountFixed: true,
      inNetwork: OrderSwapNetwork.lightning,
      outNetwork: OrderSwapNetwork.liquid,
      destinationAddress: 'tlq1destination',
      fallbackAddress: null,
      purpose: OrderSwapPurpose.receiveLightning,
      environment: OrderSwapEnvironment.testnet,
      destinationWalletId: 'liquid-wallet',
    );

    final record = (result as Ok<OrderSwapRecord, SwapFailure>).value;
    expect(record.order!.inNetwork, OrderSwapNetwork.lightning);
    expect(record.order!.outNetwork, OrderSwapNetwork.liquid);
    expect(record.order!.payinCurrency, 'BTC');
  });

  test('persists the server order before returning success', () async {
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

    final result = await _create(repository);

    expect(result, isA<Ok<OrderSwapRecord, SwapFailure>>());
    final row = await database.select(database.orderSwaps).getSingle();
    expect(row.localId, 'local-1');
    expect(row.requestId, 'request-1');
    expect(row.orderId, 'order-1');
    expect(row.localStatus, OrderSwapLocalStatus.awaitingUserConfirmation.name);
    expect(row.destination, 'invoice');
    expect(row.fallback, 'fallback');
  });

  test('persists the quoted counterpart amount', () async {
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

    final result = await repository.createOrder(
      amountSat: BigInt.from(1000),
      isInAmountFixed: false,
      inNetwork: OrderSwapNetwork.liquid,
      outNetwork: OrderSwapNetwork.lightning,
      destinationAddress: 'invoice',
      fallbackAddress: 'fallback',
      purpose: OrderSwapPurpose.sendLightning,
      environment: OrderSwapEnvironment.testnet,
      quotedCounterpartAmountSat: BigInt.from(1000),
    );

    expect(result, isA<Ok<OrderSwapRecord, SwapFailure>>());
    final row = await database.select(database.orderSwaps).getSingle();
    expect(row.quotedAmountSat, 1000);
  });

  test('maps a deviating server order to a mismatch failure', () async {
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
    ).thenAnswer((_) async => _orderModel(payinAmount: '0.00101001'));

    final result = await repository.createOrder(
      amountSat: BigInt.from(1000),
      isInAmountFixed: false,
      inNetwork: OrderSwapNetwork.liquid,
      outNetwork: OrderSwapNetwork.lightning,
      destinationAddress: 'invoice',
      fallbackAddress: 'fallback',
      purpose: OrderSwapPurpose.sendLightning,
      environment: OrderSwapEnvironment.testnet,
      quotedCounterpartAmountSat: BigInt.from(100000),
    );

    expect(result, isA<Err<OrderSwapRecord, SwapFailure>>());
    final failure = (result as Err<OrderSwapRecord, SwapFailure>).failure;
    expect(failure, isA<SwapOrderMismatchFailure>());
    expect(failure, isNot(isA<SwapCreationUnknownFailure>()));
  });

  test('gets orders belonging to either side of a wallet', () async {
    await _insertRecord(
      database,
      localId: 'source-order',
      sourceWalletId: 'wallet-1',
    );
    await _insertRecord(
      database,
      localId: 'destination-order',
      destinationWalletId: 'wallet-1',
    );
    await _insertRecord(
      database,
      localId: 'other-order',
      sourceWalletId: 'wallet-2',
    );

    final result = await repository.getOrders(walletId: 'wallet-1');

    expect(result, isA<Ok<List<OrderSwapRecord>, SwapFailure>>());
    final orders = (result as Ok<List<OrderSwapRecord>, SwapFailure>).value;
    expect(
      orders.map((order) => order.localId),
      containsAll(<String>['source-order', 'destination-order']),
    );
    expect(
      orders.map((order) => order.localId),
      isNot(contains('other-order')),
    );
  });

  test('resumes a matching active order without creating another', () async {
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
    final first = await _create(repository);

    final resumed = await _create(repository);

    expect(
      (resumed as Ok<OrderSwapRecord, SwapFailure>).value.localId,
      (first as Ok<OrderSwapRecord, SwapFailure>).value.localId,
    );
    verify(
      () => remote.createOrderSwap(
        requestId: 'request-1',
        amountSat: BigInt.from(1000),
        isInAmountFixed: false,
        inNetwork: OrderSwapNetwork.liquid,
        outNetwork: OrderSwapNetwork.lightning,
        destinationAddress: 'invoice',
        fallbackAddress: 'fallback',
      ),
    ).called(1);
  });

  test('serializes concurrent creates before checking for a match', () async {
    final firstCreateStarted = Completer<void>();
    final releaseFirstCreate = Completer<void>();
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
    ).thenAnswer((_) async {
      firstCreateStarted.complete();
      await releaseFirstCreate.future;
      return _orderModel();
    });

    final first = _create(repository);
    await firstCreateStarted.future;
    final second = _create(repository);
    await Future<void>.delayed(Duration.zero);
    verify(
      () => remote.createOrderSwap(
        requestId: 'request-1',
        amountSat: BigInt.from(1000),
        isInAmountFixed: false,
        inNetwork: OrderSwapNetwork.liquid,
        outNetwork: OrderSwapNetwork.lightning,
        destinationAddress: 'invoice',
        fallbackAddress: 'fallback',
      ),
    ).called(1);

    releaseFirstCreate.complete();
    final results = await Future.wait([first, second]);

    expect(results, everyElement(isA<Ok<OrderSwapRecord, SwapFailure>>()));
    verifyNoMoreInteractions(remote);
  });

  test('records an unknown creation outcome after a timeout', () async {
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
    ).thenThrow(const ExchangeTimeoutException('timeout'));

    final result = await _create(repository);
    final repeated = await _create(repository);

    expect(result, isA<Err<OrderSwapRecord, SwapFailure>>());
    expect(
      (repeated as Err<OrderSwapRecord, SwapFailure>).failure,
      isA<SwapCreationUnknownFailure>(),
    );
    final row = await database.select(database.orderSwaps).getSingle();
    expect(row.requestId, 'request-1');
    expect(row.orderId, isNull);
    expect(row.localStatus, OrderSwapLocalStatus.creationUnknown.name);
    verify(
      () => remote.createOrderSwap(
        requestId: 'request-1',
        amountSat: BigInt.from(1000),
        isInAmountFixed: false,
        inNetwork: OrderSwapNetwork.liquid,
        outNetwork: OrderSwapNetwork.lightning,
        destinationAddress: 'invoice',
        fallbackAddress: 'fallback',
      ),
    ).called(2);
  });

  test('replays an unknown creation with its persisted request id', () async {
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
    ).thenThrow(const ExchangeTimeoutException('timeout'));
    await _create(repository);

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

    final result = await _create(repository);

    expect(result, isA<Ok<OrderSwapRecord, SwapFailure>>());
    expect(
      (result as Ok<OrderSwapRecord, SwapFailure>).value.orderId,
      'order-1',
    );
    verify(
      () => remote.createOrderSwap(
        requestId: 'request-1',
        amountSat: BigInt.from(1000),
        isInAmountFixed: false,
        inNetwork: OrderSwapNetwork.liquid,
        outNetwork: OrderSwapNetwork.lightning,
        destinationAddress: 'invoice',
        fallbackAddress: 'fallback',
      ),
    ).called(2);
  });

  test('marks a fixed-amount server mismatch as a typed failure', () async {
    when(
      () => remote.createOrderSwap(
        requestId: 'request-1',
        amountSat: BigInt.from(1000),
        isInAmountFixed: true,
        inNetwork: OrderSwapNetwork.liquid,
        outNetwork: OrderSwapNetwork.lightning,
        destinationAddress: 'invoice',
        fallbackAddress: 'fallback',
      ),
    ).thenAnswer((_) async => _orderModel(payoutAmount: '0.00001000'));

    final result = await repository.createOrder(
      amountSat: BigInt.from(1000),
      isInAmountFixed: true,
      inNetwork: OrderSwapNetwork.liquid,
      outNetwork: OrderSwapNetwork.lightning,
      destinationAddress: 'invoice',
      fallbackAddress: 'fallback',
      purpose: OrderSwapPurpose.transfer,
      environment: OrderSwapEnvironment.testnet,
    );

    expect(result, isA<Err<OrderSwapRecord, SwapFailure>>());
    expect(
      (result as Err<OrderSwapRecord, SwapFailure>).failure,
      isA<SwapOrderMismatchFailure>(),
    );
    expect(
      (await database.select(database.orderSwaps).getSingle()).localStatus,
      OrderSwapLocalStatus.failed.name,
    );
  });

  test('does not substitute the Liquid destination as a fallback', () async {
    when(
      () => remote.createOrderSwap(
        requestId: 'request-1',
        amountSat: BigInt.from(1000),
        isInAmountFixed: true,
        inNetwork: OrderSwapNetwork.lightning,
        outNetwork: OrderSwapNetwork.liquid,
        destinationAddress: 'tlq1destination',
        fallbackAddress: null,
      ),
    ).thenThrow(
      const ExchangeRpcException(
        apiCode: 'ERR_API_400',
        field: 'fallbackAddress',
      ),
    );

    final result = await repository.createOrder(
      amountSat: BigInt.from(1000),
      isInAmountFixed: true,
      inNetwork: OrderSwapNetwork.lightning,
      outNetwork: OrderSwapNetwork.liquid,
      destinationAddress: 'tlq1destination',
      fallbackAddress: null,
      purpose: OrderSwapPurpose.receiveLightning,
      environment: OrderSwapEnvironment.testnet,
      destinationWalletId: 'wallet-1',
    );

    expect(result, isA<Err<OrderSwapRecord, SwapFailure>>());
    expect(await database.select(database.orderSwaps).get(), isEmpty);
    verify(
      () => remote.createOrderSwap(
        requestId: 'request-1',
        amountSat: BigInt.from(1000),
        isInAmountFixed: true,
        inNetwork: OrderSwapNetwork.lightning,
        outNetwork: OrderSwapNetwork.liquid,
        destinationAddress: 'tlq1destination',
        fallbackAddress: null,
      ),
    ).called(1);
    verifyNoMoreInteractions(remote);
  });

  test(
    'deletes a locally prepared request after a deterministic rejection',
    () async {
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
      ).thenThrow(
        const ExchangeRpcException(
          apiCode: 'ERR_VALIDATION_ENUM',
          logMessage: 'invalid',
        ),
      );

      final result = await _create(repository);

      expect(result, isA<Err<OrderSwapRecord, SwapFailure>>());
      expect(await database.select(database.orderSwaps).get(), isEmpty);
    },
  );

  test(
    'recovers an interrupted creating state without retrying create',
    () async {
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
      ).thenThrow(const ExchangeTimeoutException('timeout'));
      await _create(repository);
      await (database.update(
        database.orderSwaps,
      )..where((table) => table.localId.equals('local-1'))).write(
        OrderSwapsCompanion(
          localStatus: Value(OrderSwapLocalStatus.creating.name),
        ),
      );
      now = now.add(const Duration(minutes: 1));

      final result = await repository.getPendingOrders();

      final records = (result as Ok<List<OrderSwapRecord>, SwapFailure>).value;
      expect(records.single.localStatus, OrderSwapLocalStatus.creationUnknown);
      final row = await database.select(database.orderSwaps).getSingle();
      expect(row.localStatus, OrderSwapLocalStatus.creationUnknown.name);
      verify(
        () => remote.createOrderSwap(
          requestId: 'request-1',
          amountSat: BigInt.from(1000),
          isInAmountFixed: false,
          inNetwork: OrderSwapNetwork.liquid,
          outNetwork: OrderSwapNetwork.lightning,
          destinationAddress: 'invoice',
          fallbackAddress: 'fallback',
        ),
      ).called(1);
    },
  );

  test('does not mark a recent in-flight creation as unknown', () async {
    await _insertRecord(database, localId: 'local-1');

    final result = await repository.getPendingOrders();

    final records = (result as Ok<List<OrderSwapRecord>, SwapFailure>).value;
    expect(records.single.localStatus, OrderSwapLocalStatus.creating);
    final row = await database.select(database.orderSwaps).getSingle();
    expect(row.localStatus, OrderSwapLocalStatus.creating.name);
  });

  test(
    'persists the exact signed payload before and across broadcast',
    () async {
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
      await _create(repository);

      await repository.savePreparedPayin(
        localId: 'local-1',
        signedTransaction: 'signed-pset',
        isPsbt: false,
      );
      await repository.markBroadcastUnknown('local-1');
      final result = await repository.markPayinBroadcast(
        localId: 'local-1',
        transactionId: 'txid-1',
      );

      final record = (result as Ok<OrderSwapRecord, SwapFailure>).value;
      expect(record.localStatus, OrderSwapLocalStatus.payinBroadcast);
      expect(record.signedPayinTransaction, 'signed-pset');
      expect(record.payinIsPsbt, isFalse);
      expect(record.localPayinTransactionId, 'txid-1');
      final row = await database.select(database.orderSwaps).getSingle();
      expect(row.signedPayinTransaction, 'signed-pset');
      expect(row.payinIsPsbt, isFalse);
      expect(row.localPayinTransactionId, 'txid-1');
    },
  );

  test('does not replace a prepared payin with a different payload', () async {
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
    await _create(repository);
    await repository.savePreparedPayin(
      localId: 'local-1',
      signedTransaction: 'signed-pset',
      isPsbt: false,
    );

    final result = await repository.savePreparedPayin(
      localId: 'local-1',
      signedTransaction: 'different-pset',
      isPsbt: false,
    );

    expect(
      (result as Err<OrderSwapRecord, SwapFailure>).failure,
      isA<SwapInvalidStateFailure>(),
    );
    final row = await database.select(database.orderSwaps).getSingle();
    expect(row.signedPayinTransaction, 'signed-pset');
  });

  test('explicitly replaces a prepared payin before broadcast', () async {
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
    await _create(repository);
    await repository.savePreparedPayin(
      localId: 'local-1',
      signedTransaction: 'signed-pset',
      isPsbt: false,
    );

    final result = await repository.replacePreparedPayin(
      localId: 'local-1',
      signedTransaction: 'replacement-pset',
      isPsbt: false,
    );

    final record = (result as Ok<OrderSwapRecord, SwapFailure>).value;
    expect(record.localStatus, OrderSwapLocalStatus.readyToBroadcast);
    expect(record.signedPayinTransaction, 'replacement-pset');
    final row = await database.select(database.orderSwaps).getSingle();
    expect(row.signedPayinTransaction, 'replacement-pset');
  });

  test('rejects a first broadcast after the confirmation deadline', () async {
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
    await _create(repository);
    await repository.savePreparedPayin(
      localId: 'local-1',
      signedTransaction: 'signed-pset',
      isPsbt: false,
    );
    now = DateTime.utc(2026, 8, 5, 12, 6);

    final result = await repository.markBroadcastUnknown('local-1');

    expect(
      (result as Err<OrderSwapRecord, SwapFailure>).failure,
      isA<SwapOrderExpiredFailure>(),
    );
    final row = await database.select(database.orderSwaps).getSingle();
    expect(row.localStatus, OrderSwapLocalStatus.readyToBroadcast.name);
    expect(row.signedPayinTransaction, 'signed-pset');
  });

  test('rejects an unknown broadcast after the deadline', () async {
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
    await _create(repository);
    await repository.savePreparedPayin(
      localId: 'local-1',
      signedTransaction: 'signed-pset',
      isPsbt: false,
    );
    await repository.markBroadcastUnknown('local-1');
    now = DateTime.utc(2026, 8, 5, 12, 6);

    final result = await repository.markBroadcastUnknown('local-1');

    expect(
      (result as Err<OrderSwapRecord, SwapFailure>).failure,
      isA<SwapOrderExpiredFailure>(),
    );
  });

  test(
    'expires an unfunded order when refreshing after its deadline',
    () async {
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
      when(
        () => remote.getOrderSwapSummary('order-1'),
      ).thenAnswer((_) async => _orderModel());
      await _create(repository);
      now = DateTime.utc(2026, 8, 5, 12, 6);

      final result = await repository.refreshOrder('local-1');

      final record = (result as Ok<OrderSwapRecord, SwapFailure>).value;
      expect(record.localStatus, OrderSwapLocalStatus.expired);
    },
  );

  test('maps known server terminal statuses', () async {
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
    await _create(repository);

    for (final (serverStatus, expected) in [
      ('Payment deadline expired', OrderSwapLocalStatus.expired),
      ('Rejected', OrderSwapLocalStatus.failed),
      ('Canceled', OrderSwapLocalStatus.failed),
    ]) {
      when(
        () => remote.getOrderSwapSummary('order-1'),
      ).thenAnswer((_) async => _orderModel(orderStatus: serverStatus));
      await (database.update(
        database.orderSwaps,
      )..where((table) => table.localId.equals('local-1'))).write(
        OrderSwapsCompanion(
          localStatus: Value(
            OrderSwapLocalStatus.awaitingUserConfirmation.name,
          ),
        ),
      );

      final result = await repository.refreshOrder('local-1');

      expect(
        (result as Ok<OrderSwapRecord, SwapFailure>).value.localStatus,
        expected,
      );
    }
  });

  test('maps a terminal payout when the order status is unknown', () async {
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
    await _create(repository);
    when(() => remote.getOrderSwapSummary('order-1')).thenAnswer(
      (_) async => _orderModel(
        orderStatus: 'Future provider status',
        payoutStatus: 'Refunded',
      ),
    );

    final result = await repository.refreshOrder('local-1');

    expect(
      (result as Ok<OrderSwapRecord, SwapFailure>).value.localStatus,
      OrderSwapLocalStatus.refunded,
    );
  });

  test('a late refresh does not roll back broadcast state', () async {
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
    await _create(repository);
    await repository.savePreparedPayin(
      localId: 'local-1',
      signedTransaction: 'signed-pset',
      isPsbt: false,
    );
    final summary = Completer<OrderSwapModel>();
    when(
      () => remote.getOrderSwapSummary('order-1'),
    ).thenAnswer((_) => summary.future);

    final refresh = repository.refreshOrder('local-1');
    await untilCalled(() => remote.getOrderSwapSummary('order-1'));
    await repository.markBroadcastUnknown('local-1');
    summary.complete(_orderModel());
    await refresh;

    final row = await database.select(database.orderSwaps).getSingle();
    expect(row.localStatus, OrderSwapLocalStatus.broadcastUnknown.name);
    expect(row.signedPayinTransaction, 'signed-pset');
  });

  test('a late refresh cannot regress a completed order', () async {
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
    await _create(repository);
    await (database.update(
      database.orderSwaps,
    )..where((table) => table.localId.equals('local-1'))).write(
      OrderSwapsCompanion(
        localStatus: Value(OrderSwapLocalStatus.completed.name),
      ),
    );
    when(() => remote.getOrderSwapSummary('order-1')).thenAnswer(
      (_) async =>
          _orderModel(orderStatus: 'In progress', payinStatus: 'Completed'),
    );

    final result = await repository.refreshOrder('local-1');

    expect(
      (result as Ok<OrderSwapRecord, SwapFailure>).value.localStatus,
      OrderSwapLocalStatus.completed,
    );
  });

  test('rejects a server order that changes the payout destination', () async {
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
    ).thenAnswer(
      (_) async => _orderModel(lightningInvoice: 'attacker-invoice'),
    );

    final result = await _create(repository);

    expect(result, isA<Err<OrderSwapRecord, SwapFailure>>());
    expect(
      (result as Err<OrderSwapRecord, SwapFailure>).failure,
      isA<SwapOrderMismatchFailure>(),
    );
  });

  test(
    'markBroadcastUnknown reports invalid state when no server order exists',
    () async {
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
      ).thenThrow(const ExchangeTimeoutException('timeout'));
      await _create(repository);

      final result = await repository.markBroadcastUnknown('local-1');

      expect(
        (result as Err<OrderSwapRecord, SwapFailure>).failure,
        isA<SwapInvalidStateFailure>(),
      );
    },
  );

  test(
    'maps entity invariant failures during refresh instead of throwing',
    () async {
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
      await repository.createOrder(
        amountSat: BigInt.from(1000),
        isInAmountFixed: false,
        inNetwork: OrderSwapNetwork.liquid,
        outNetwork: OrderSwapNetwork.lightning,
        destinationAddress: 'invoice',
        fallbackAddress: 'fallback',
        purpose: OrderSwapPurpose.sendLightning,
        environment: OrderSwapEnvironment.testnet,
        sourceWalletId: 'wallet-1',
        quotedCounterpartAmountSat: BigInt.from(1010),
      );
      // A pinned identity field (the payin invoice) changes on refresh: this
      // is a genuine entity invariant violation (not the creation-only quote
      // tolerance) and must still be mapped to a typed failure rather than
      // thrown.
      when(() => remote.getOrderSwapSummary('order-1')).thenAnswer(
        (_) async => _orderModel(lightningInvoice: 'attacker-invoice'),
      );

      final result = await repository.refreshOrder('local-1');

      expect(result, isA<Err<OrderSwapRecord, SwapFailure>>());
      expect(
        (result as Err<OrderSwapRecord, SwapFailure>).failure,
        isA<SwapOrderMismatchFailure>(),
      );
    },
  );

  test('refresh accepts a legitimate mutable settlement amount beyond the '
      'creation-only quote tolerance (H4)', () async {
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
    await repository.createOrder(
      amountSat: BigInt.from(1000),
      isInAmountFixed: false,
      inNetwork: OrderSwapNetwork.liquid,
      outNetwork: OrderSwapNetwork.lightning,
      destinationAddress: 'invoice',
      fallbackAddress: 'fallback',
      purpose: OrderSwapPurpose.sendLightning,
      environment: OrderSwapEnvironment.testnet,
      sourceWalletId: 'wallet-1',
      quotedCounterpartAmountSat: BigInt.from(1010),
    );
    // The settled payin amount deviates far beyond the original quote
    // tolerance (>1%), but this is a legitimate mutable settlement update
    // reported on refresh, not a new quote to validate.
    when(
      () => remote.getOrderSwapSummary('order-1'),
    ).thenAnswer((_) async => _orderModel(payinAmount: '0.00010000'));

    final result = await repository.refreshOrder('local-1');

    expect(result, isA<Ok<OrderSwapRecord, SwapFailure>>());
    expect(
      (result as Ok<OrderSwapRecord, SwapFailure>).value.order!.payinAmountSat,
      BigInt.from(10000),
    );
  });

  test(
    'rejects a refreshed order that changes the pinned payin address (H3)',
    () async {
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
      await _create(repository);
      when(() => remote.getOrderSwapSummary('order-1')).thenAnswer(
        (_) async => _orderModel(lightningInvoice: 'attacker-invoice'),
      );

      final result = await repository.refreshOrder('local-1');

      expect(result, isA<Err<OrderSwapRecord, SwapFailure>>());
      expect(
        (result as Err<OrderSwapRecord, SwapFailure>).failure,
        isA<SwapOrderMismatchFailure>(),
      );
      // The local record must be preserved unchanged: the payin invoice on
      // disk is still the original one, not the attacker-supplied one.
      final row = await database.select(database.orderSwaps).getSingle();
      expect(row.lightningInvoice, 'invoice');
      expect(
        row.localStatus,
        OrderSwapLocalStatus.awaitingUserConfirmation.name,
      );
    },
  );

  test('refreshes a failed order with moved funds into a truthful refunded '
      'state and keeps it pollable (H6)', () async {
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
    await _create(repository);
    await repository.savePreparedPayin(
      localId: 'local-1',
      signedTransaction: 'signed-pset',
      isPsbt: false,
    );
    await repository.markBroadcastUnknown('local-1');
    await repository.markPayinBroadcast(
      localId: 'local-1',
      transactionId: 'txid-1',
    );
    // Simulate a provisional local `failed` status recorded while payin
    // funds had already moved (localPayinTransactionId is preserved).
    await (database.update(
      database.orderSwaps,
    )..where((table) => table.localId.equals('local-1'))).write(
      OrderSwapsCompanion(localStatus: Value(OrderSwapLocalStatus.failed.name)),
    );

    final pending = await repository.getPendingOrders();
    expect(
      (pending as Ok<List<OrderSwapRecord>, SwapFailure>).value.map(
        (record) => record.localId,
      ),
      contains('local-1'),
    );

    when(() => remote.getOrderSwapSummary('order-1')).thenAnswer(
      (_) async =>
          _orderModel(orderStatus: 'In progress', payoutStatus: 'Refunded'),
    );

    final result = await repository.refreshOrder('local-1');

    expect(
      (result as Ok<OrderSwapRecord, SwapFailure>).value.localStatus,
      OrderSwapLocalStatus.refunded,
    );
    final row = await database.select(database.orderSwaps).getSingle();
    expect(row.localStatus, OrderSwapLocalStatus.refunded.name);
  });

  test('keeps an unfunded failed creation record terminal and non-pollable '
      '(H6)', () async {
    when(
      () => remote.createOrderSwap(
        requestId: 'request-1',
        amountSat: BigInt.from(1000),
        isInAmountFixed: true,
        inNetwork: OrderSwapNetwork.liquid,
        outNetwork: OrderSwapNetwork.lightning,
        destinationAddress: 'invoice',
        fallbackAddress: 'fallback',
      ),
    ).thenAnswer((_) async => _orderModel(payoutAmount: '0.00001000'));

    // The server's payin amount (default 1010 sats) does not match the
    // fixed requested amount (1000 sats), which is rejected as an
    // ArgumentError and marks the record failed with no server order and
    // no funds moved.
    final result = await repository.createOrder(
      amountSat: BigInt.from(1000),
      isInAmountFixed: true,
      inNetwork: OrderSwapNetwork.liquid,
      outNetwork: OrderSwapNetwork.lightning,
      destinationAddress: 'invoice',
      fallbackAddress: 'fallback',
      purpose: OrderSwapPurpose.transfer,
      environment: OrderSwapEnvironment.testnet,
    );

    expect(result, isA<Err<OrderSwapRecord, SwapFailure>>());
    final row = await database.select(database.orderSwaps).getSingle();
    expect(row.localStatus, OrderSwapLocalStatus.failed.name);
    expect(row.orderId, isNull);
    expect(row.localPayinTransactionId, isNull);

    final pending = await repository.getPendingOrders();
    expect((pending as Ok<List<OrderSwapRecord>, SwapFailure>).value, isEmpty);

    final refreshed = await repository.refreshOrder('local-1');
    expect(refreshed, isA<Err<OrderSwapRecord, SwapFailure>>());
    expect(
      (refreshed as Err<OrderSwapRecord, SwapFailure>).failure,
      isA<SwapOrderNotFoundFailure>(),
    );
  });

  test('does not accept a response that changes the fixed output', () async {
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
    ).thenAnswer((_) async => _orderModel(payoutAmount: '0.00000999'));

    final result = await _create(repository);

    expect(result, isA<Err<OrderSwapRecord, SwapFailure>>());
    final row = await database.select(database.orderSwaps).getSingle();
    expect(row.localStatus, OrderSwapLocalStatus.failed.name);
  });

  test('completed orders stop awaiting labels only after marking', () async {
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
    await _create(repository);
    await (database.update(
      database.orderSwaps,
    )..where((table) => table.localId.equals('local-1'))).write(
      OrderSwapsCompanion(
        localStatus: Value(OrderSwapLocalStatus.completed.name),
      ),
    );

    final before = await repository.getOrdersAwaitingLabels(
      purpose: OrderSwapPurpose.sendLightning,
    );
    expect(
      (before as Ok<List<OrderSwapRecord>, SwapFailure>).value,
      hasLength(1),
    );

    final marked = await repository.markLabelsApplied(
      localId: 'local-1',
      appliedAt: now,
    );
    expect(
      (marked as Ok<OrderSwapRecord, SwapFailure>).value.labelsAppliedAt,
      now,
    );
    final after = await repository.getOrdersAwaitingLabels(
      purpose: OrderSwapPurpose.sendLightning,
    );
    expect((after as Ok<List<OrderSwapRecord>, SwapFailure>).value, isEmpty);
  });

  test('maps watched order storage errors to a typed failure', () async {
    await _insertRecord(
      database,
      localId: 'watched-order',
      sourceWalletId: 'wallet-1',
    );
    final expectation = expectLater(
      repository.watchOrder('watched-order'),
      emitsInOrder([
        isA<Ok<OrderSwapRecord, SwapFailure>>(),
        isA<Err<OrderSwapRecord, SwapFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<SwapStorageFailure>(),
        ),
      ]),
    );

    await Future<void>.delayed(Duration.zero);
    await (database.delete(
      database.orderSwaps,
    )..where((table) => table.localId.equals('watched-order'))).go();

    await expectation;
  });
}

Future<Result<OrderSwapRecord, SwapFailure>> _create(
  OrderSwapRepositoryImpl repository,
) => repository.createOrder(
  amountSat: BigInt.from(1000),
  isInAmountFixed: false,
  inNetwork: OrderSwapNetwork.liquid,
  outNetwork: OrderSwapNetwork.lightning,
  destinationAddress: 'invoice',
  fallbackAddress: 'fallback',
  purpose: OrderSwapPurpose.sendLightning,
  environment: OrderSwapEnvironment.testnet,
  sourceWalletId: 'wallet-1',
  note: 'note',
);

Future<void> _insertRecord(
  SqliteDatabase database, {
  required String localId,
  String? sourceWalletId,
  String? destinationWalletId,
}) => database
    .into(database.orderSwaps)
    .insert(
      OrderSwapsCompanion.insert(
        localId: localId,
        purpose: OrderSwapPurpose.sendLightning.name,
        environment: OrderSwapEnvironment.testnet.name,
        inNetwork: OrderSwapNetwork.bitcoin.name,
        outNetwork: OrderSwapNetwork.lightning.name,
        isInAmountFixed: false,
        requestedAmountSat: 1000,
        sourceWalletId: Value(sourceWalletId),
        destinationWalletId: Value(destinationWalletId),
        destination: 'invoice-$localId',
        fallback: 'fallback-$localId',
        createdAt: DateTime.utc(2026, 8, 5, 12),
        localStatus: OrderSwapLocalStatus.creating.name,
      ),
    );

OrderSwapModel _orderModel({
  String payinAmount = '0.00001010',
  String payoutAmount = '0.00001000',
  String orderStatus = 'Awaiting payment',
  String payinStatus = 'In progress',
  String payoutStatus = 'In progress',
  String lightningInvoice = 'invoice',
  String liquidAddress = 'liquid-payin',
}) => OrderSwapModel(
  orderId: 'order-1',
  orderNumber: 1,
  payinAmount: payinAmount,
  payoutAmount: payoutAmount,
  payinCurrency: 'LBTC',
  payoutCurrency: 'BTCLN',
  payinMethod: 'Liquid',
  payoutMethod: 'Lightning',
  orderType: 'Swap',
  orderStatus: orderStatus,
  payinStatus: payinStatus,
  payoutStatus: payoutStatus,
  messageCode: 'ORDER_CREATED',
  lightningInvoice: lightningInvoice,
  liquidAddress: liquidAddress,
  createdAt: DateTime.utc(2026, 8, 5, 12),
  confirmationDeadline: DateTime.utc(2026, 8, 5, 12, 5),
);

OrderSwapQuoteModel _quoteModel() => const OrderSwapQuoteModel(
  inAmount: '0.00001010',
  outAmount: '0.00001000',
  inCurrency: 'BTC',
  outCurrency: 'LBTC',
  feePercents: ['1'],
  warnings: [],
);

OrderSwapModel _liquidToBitcoinOrderModel() => OrderSwapModel(
  orderId: 'liquid-to-bitcoin-order',
  orderNumber: 3,
  payinAmount: '0.00001000',
  payoutAmount: '0.00000990',
  payinCurrency: 'LBTC',
  payoutCurrency: 'BTC',
  payinMethod: 'Liquid',
  payoutMethod: 'Bitcoin',
  orderType: 'Swap',
  orderStatus: 'Awaiting payment',
  payinStatus: 'In progress',
  payoutStatus: 'Not started',
  messageCode: 'ORDER_CREATED',
  bitcoinAddress: 'tb1destination',
  liquidAddress: 'tlq1payin',
  createdAt: DateTime.utc(2026, 8, 5, 12),
  confirmationDeadline: DateTime.utc(2026, 8, 5, 12, 5),
);

OrderSwapModel _receiveOrderModel() => OrderSwapModel(
  orderId: 'receive-order',
  orderNumber: 2,
  payinAmount: '0.00010000',
  payoutAmount: '0.00009900',
  payinCurrency: 'BTC',
  payoutCurrency: 'LBTC',
  payinMethod: 'Lightning Invoice (BOLT11)',
  payoutMethod: 'Liquid Network',
  orderType: 'Swap',
  orderStatus: 'In_pending',
  payinStatus: 'Awaiting payment',
  payoutStatus: 'Not started',
  messageCode: 'PAYMENT_NOT_DETECTED',
  lightningInvoice: 'lntb-invoice',
  liquidAddress: 'tlq1destination',
  createdAt: DateTime.utc(2026, 8, 5, 12),
  confirmationDeadline: DateTime.utc(2026, 8, 5, 12, 5),
);
