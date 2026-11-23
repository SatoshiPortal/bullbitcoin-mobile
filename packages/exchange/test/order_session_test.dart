import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bbx_api/bbx_api_testing.dart';
import 'package:dio/dio.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

import 'bbx_api_test_http.dart';
import 'order_json_fixture.dart';

final class _HeldResponse implements HttpClientAdapter {
  final started = Completer<void>();
  final response = Completer<ResponseBody>();
  final requests = <RequestOptions>[];
  final ResponseBody? followUp;

  _HeldResponse({this.followUp});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (followUp case final next? when requests.length > 1) return next;
    if (!started.isCompleted) started.complete();
    return response.future;
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('order requests never select credentials for another backend', () async {
    final exchange = exchangeWithTransportForTesting(
      readSession: () async => const Ok((
        environment: ExchangeEnvironment.testnet,
        epoch: 0,
        apiKey: 'synthetic-session-key',
      )),
      openClient: (_, _) => fail('A mismatched backend must not open a client'),
    );
    expect(
      await exchange.orders(ExchangeEnvironment.mainnet).getOrders(),
      isA<Err<List<Order>, ExchangeFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<ExchangeOperationStaleFailure>(),
      ),
    );
  });

  test('a current HTTP 401 is not an empty order history', () async {
    final http = FakeBbxHttp(status: 401);
    final orders = testExchangeOrders(http);
    expect(
      await orders.getOrders(),
      isA<Err<List<Order>, ExchangeFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<ExchangeSessionRejectedFailure>(),
      ),
    );
    expect(http.requests, hasLength(1));
  });

  for (final (status, write) in [
    (200, false),
    (401, false),
    (200, true),
    (401, true),
  ]) {
    test('an order ${write ? 'write' : 'read'} completing with $status '
        'as the session changes', () async {
      var epoch = 0;
      final http = _HeldResponse();
      final exchange = exchangeWithTransportForTesting(
        readSession: () async => Ok((
          environment: ExchangeEnvironment.testnet,
          epoch: epoch,
          apiKey: 'synthetic-session-key',
        )),
        openClient: (endpoint, readKey) => bbxForTesting(
          endpoint: endpoint.toString(),
          adapter: http,
          readActiveApiKey: readKey,
        ),
      );
      final orders = exchange.orders(ExchangeEnvironment.testnet);
      final pending = write
          ? orders.confirmBuyOrder('order-1')
          : orders.getOrder('order-1');
      await http.started.future;
      epoch++;
      http.response.complete(
        ResponseBody.fromString(
          jsonEncode({'result': orderJsonFixture()}),
          status,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      expect(
        await pending,
        write && status == 200
            ? isA<Ok<BuyOrder, ExchangeFailure>>()
            : isA<Err<Order, ExchangeFailure>>().having(
                (result) => result.failure,
                'failure',
                isA<ExchangeOperationStaleFailure>(),
              ),
      );
      expect(http.requests, hasLength(1));
    });
  }

  for (final write in [false, true]) {
    test('a recipient ${write ? 'write' : 'read'} completes as the session '
        'changes', () async {
      var epoch = 0;
      final http = _HeldResponse();
      final exchange = exchangeWithTransportForTesting(
        readSession: () async => Ok((
          environment: ExchangeEnvironment.testnet,
          epoch: epoch,
          apiKey: 'synthetic-session-key',
        )),
        openClient: (endpoint, readKey) => bbxForTesting(
          endpoint: endpoint.toString(),
          adapter: http,
          readActiveApiKey: readKey,
        ),
      );
      final pending = write
          ? exchange.recipients.updateInteracSecurityDetails(
              recipientId: 'synthetic-recipient',
              email: 'test@example.invalid',
              securityQuestion: null,
              securityAnswer: null,
              isTestnet: true,
            )
          : exchange.recipients.checkSinpe(
              phoneNumber: '88888888',
              isTestnet: true,
            );
      await http.started.future;
      epoch++;
      http.response.complete(
        ResponseBody.fromString(
          write ? '{"result":null}' : '{"result":{"ownerName":"Test Owner"}}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      expect(
        await pending,
        write
            ? isA<Ok<void, RecipientsFailure>>()
            : isA<Err<String, RecipientsFailure>>().having(
                (result) => result.failure.logMessage,
                'failure',
                'ExchangeOperationStaleFailure',
              ),
      );
      expect(http.requests, hasLength(1));
    });
  }

  for (final changeSession in [false, true]) {
    test('confirmed withdrawal preserves success when the Interac update '
        '${changeSession ? 'would cross a session' : 'is refused'}', () async {
      var epoch = 0;
      final http = _HeldResponse(
        followUp: ResponseBody.fromString(
          '{"error":{"code":-32603}}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      final exchange = exchangeWithTransportForTesting(
        readSession: () async => Ok((
          environment: ExchangeEnvironment.testnet,
          epoch: epoch,
          apiKey: 'synthetic-session-key',
        )),
        openClient: (endpoint, readKey) => bbxForTesting(
          endpoint: endpoint.toString(),
          adapter: http,
          readActiveApiKey: readKey,
        ),
      );

      final pending = exchange
          .orders(ExchangeEnvironment.testnet)
          .confirmWithdrawOrder(
            'order-1',
            interacUpdate: (
              recipientId: 'synthetic-recipient',
              email: 'test@example.invalid',
              securityQuestion: 'Favourite city?',
              securityAnswer: 'Montreal',
            ),
          );
      await http.started.future;
      if (changeSession) epoch++;
      http.response.complete(
        ResponseBody.fromString(
          jsonEncode({'result': orderJsonFixture(orderType: 'Withdraw')}),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );

      expect(await pending, isA<Ok<WithdrawOrder, ExchangeFailure>>());
      expect(http.requests.map((request) => (request.data as Map)['method']), [
        'confirmOrderSummary',
        if (!changeSession) 'updateMyRecipient',
      ]);
    });
  }

  for (final environment in ExchangeEnvironment.values) {
    test(
      'default wallet writes succeed using the ${environment.name} session',
      () async {
        final endpoints = <Uri>[];
        final http = FakeBbxHttp(
          body: {
            'result': {
              'element': {
                'recipientId': 'synthetic',
                'recipientType': 'OUT_BITCOIN_ADDRESS',
              },
            },
          },
        );
        final exchange = exchangeWithTransportForTesting(
          readSession: () async => http.requests.isEmpty
              ? Ok((
                  environment: environment,
                  epoch: 0,
                  apiKey: 'synthetic-session-key',
                ))
              : const Err(ExchangeCredentialReadFailure()),
          openClient: (endpoint, readKey) {
            endpoints.add(endpoint);
            return bbxForTesting(
              endpoint: endpoint.toString(),
              adapter: http,
              readActiveApiKey: readKey,
            );
          },
        );
        final result = await exchange.deleteDefaultWallet(
          recipientId: 'synthetic',
          walletType: WalletAddressType.bitcoin,
          address: 'synthetic-address',
        );
        expect(result, isA<Ok<void, ExchangeFailure>>());
        expect(endpoints.single.host, startsWith(environment.name));
      },
    );
  }
}
