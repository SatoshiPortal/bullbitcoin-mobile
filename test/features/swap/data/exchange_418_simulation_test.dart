import 'dart:io';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/swap/data/datasources/exchange_public_api_datasource.dart';
import 'package:bb_mobile/features/swap/data/datasources/order_swap_local_datasource.dart';
import 'package:bb_mobile/features/swap/data/order_swap_repository_impl.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_network.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_record.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// End-to-end simulation of an Exchange server returning HTTP 418.
///
/// Starts a real local HTTP server that answers 418 to every request, then
/// verifies the full chain: datasource → typed exception → repository →
/// typed failure. This proves the fallback signal propagates correctly
/// through real HTTP, not just a mocked interceptor.
void main() {
  late HttpServer server;
  late int port;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    port = server.port;
    server.listen((request) {
      request.response
        ..statusCode = 418
        ..write("I'm a teapot")
        ..close();
    });
  });

  tearDown(() => server.close(force: true));

  Dio buildDio() => Dio(
    BaseOptions(
      baseUrl: 'http://127.0.0.1:$port',
      validateStatus: (_) => true,
    ),
  );

  test('datasource throws ExchangeProviderUnavailableException on 418', () async {
    final datasource = ExchangePublicApiDatasource(buildDio());

    await expectLater(
      datasource.getBestSwapOption(
        amountSat: BigInt.from(100000),
        isInAmountFixed: true,
        inNetwork: OrderSwapNetwork.liquid,
        outNetwork: OrderSwapNetwork.bitcoin,
      ),
      throwsA(isA<ExchangeProviderUnavailableException>()),
    );
  });

  test('repository maps 418 to SwapProviderUnavailableFailure on createOrder', () async {
    final database = SqliteDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = OrderSwapRepositoryImpl(
      ExchangePublicApiDatasource(buildDio()),
      ExchangePublicApiDatasource(buildDio()),
      OrderSwapLocalDatasource(database),
    );

    final result = await repository.createOrder(
      amountSat: BigInt.from(100000),
      isInAmountFixed: true,
      inNetwork: OrderSwapNetwork.liquid,
      outNetwork: OrderSwapNetwork.bitcoin,
      destinationAddress: 'bc1qdestination',
      fallbackAddress: null,
      purpose: OrderSwapPurpose.autoswap,
      environment: OrderSwapEnvironment.mainnet,
    );

    expect(result, isA<Err>());
    expect(
      (result as Err).failure,
      isA<SwapProviderUnavailableFailure>(),
    );
  });

  test('repository maps 418 to SwapProviderUnavailableFailure on getQuote', () async {
    final database = SqliteDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = OrderSwapRepositoryImpl(
      ExchangePublicApiDatasource(buildDio()),
      ExchangePublicApiDatasource(buildDio()),
      OrderSwapLocalDatasource(database),
    );

    final result = await repository.getQuote(
      environment: OrderSwapEnvironment.mainnet,
      amountSat: BigInt.from(100000),
      isInAmountFixed: true,
      inNetwork: OrderSwapNetwork.liquid,
      outNetwork: OrderSwapNetwork.bitcoin,
    );

    expect(result, isA<Err>());
    expect(
      (result as Err).failure,
      isA<SwapProviderUnavailableFailure>(),
    );
  });
}
