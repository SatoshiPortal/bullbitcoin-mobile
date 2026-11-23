import 'dart:typed_data';

import 'package:exchange/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:bbx_api/bbx_api.dart'
    show Bbx, BbxFailure, BbxCredentialUnavailableFailure;
import 'package:bbx_api/bbx_api_testing.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../features/exchange/data/bbx_api_test_http.dart';

class _NoNetwork implements HttpClientAdapter {
  var sends = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    sends++;
    throw StateError('No request should pass authentication');
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _NoNetwork network;
  late Bbx api;
  late Exchange user;
  late ExchangeOrders orders;
  Result<String?, ExchangeFailure> credential = const Ok(null);

  setUp(() {
    credential = const Ok(null);
    network = _NoNetwork();
    api = bbxForTesting(
      endpoint: testBbxEndpoint,
      adapter: network,
      readActiveApiKey: () async => switch (credential) {
        Ok(:final value) => Ok<String?, BbxFailure>(value),
        Err() => const Err<String?, BbxFailure>(
          BbxCredentialUnavailableFailure(),
        ),
      },
    );
    user = exchangeWithTransportForTesting(
      readSession: () async => switch (credential) {
        Ok(:final value) => Ok((
          environment: ExchangeEnvironment.testnet,
          epoch: 0,
          apiKey: value,
        )),
        Err() => const Err(ExchangeCredentialReadFailure()),
      },
      openClient: (endpoint, readKey) => bbxForTesting(
        endpoint: endpoint.toString(),
        adapter: network,
        readActiveApiKey: readKey,
      ),
    );
    orders = user.orders(ExchangeEnvironment.testnet);
  });
  tearDown(() {
    expect(network.sends, 0);
  });

  for (final storageFailure in [false, true]) {
    test(
      'EUR sell payout preserves credential refusal: $storageFailure',
      () async {
        credential = storageFailure
            ? const Err(ExchangeCredentialReadFailure())
            : const Ok(null);
        expect(
          await orders.placePayOrder(
            orderAmount: const FiatAmount(100),
            recipientId: 'own-account',
            paymentProcessor: SepaPaymentProcessor.regular,
            network: OrderBitcoinNetwork.bitcoin,
          ),
          isA<Err>().having(
            (r) => r.failure,
            'failure',
            storageFailure
                ? isA<ExchangeCredentialReadFailure>()
                : isA<ExchangeNotAuthenticatedFailure>(),
          ),
        );
      },
    );
  }

  test(
    'no session yields contextual empty results or authentication failures',
    () async {
      final profile = await user.getUserSummary(ExchangeEnvironment.testnet);
      expect(
        profile,
        isA<Err>().having(
          (r) => r.failure,
          'profile',
          isA<ExchangeNotAuthenticatedFailure>(),
        ),
      );
      final announcements = await user.listAnnouncements(
        ExchangeEnvironment.testnet,
      );
      expect(
        announcements,
        isA<Ok>().having((r) => r.value, 'announcements', isEmpty),
      );
      final messages = await user.getSupportMessages();
      expect(
        messages,
        isA<Err>().having(
          (r) => r.failure,
          'chat',
          isA<ExchangeNotAuthenticatedFailure>(),
        ),
      );
      final history = await orders.getOrders();
      expect(history, isA<Ok>().having((r) => r.value, 'history', isEmpty));
      expect(
        await orders.getOrder('order'),
        isA<Err>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeNotAuthenticatedFailure>(),
        ),
      );
    },
  );

  test(
    'storage failure is not presented as logout or empty account history',
    () async {
      credential = const Err(ExchangeCredentialReadFailure());
      expect(
        await user.getUserSummary(ExchangeEnvironment.testnet),
        isA<Err>().having(
          (r) => r.failure,
          'profile',
          isA<ExchangeCredentialReadFailure>(),
        ),
      );
      expect(
        await user.listAnnouncements(ExchangeEnvironment.testnet),
        isA<Err>().having(
          (r) => r.failure,
          'announcements',
          isA<ExchangeCredentialReadFailure>(),
        ),
      );
      expect(
        await user.getSupportMessages(),
        isA<Err>().having(
          (r) => r.failure,
          'chat',
          isA<ExchangeChatLoadMessagesFailure>(),
        ),
      );
      expect(
        await orders.getOrders(),
        isA<Err>().having(
          (r) => r.failure,
          'history',
          isA<ExchangeCredentialReadFailure>(),
        ),
      );
      expect(
        await orders.getOrderByTxId('tx'),
        isA<Err>().having(
          (r) => r.failure,
          'lookup',
          isA<ExchangeCredentialReadFailure>(),
        ),
      );
    },
  );
  test(
    'shared Dio features distinguish missing credentials from read failures',
    () async {
      final funding = user.funding;
      final recipients = BbxApiRecipientsRepository(api: api);
      final limits = user.limitOrders;
      expect(
        await funding.listInstitutions(jurisdiction: Jurisdiction.canada),
        isA<Err>().having(
          (r) => r.failure,
          'funding',
          isA<ExchangeNotAuthenticatedFailure>(),
        ),
      );
      expect(
        await recipients.listRecipients(isTestnet: true),
        isA<Err>().having(
          (r) => r.failure,
          'recipients',
          isA<RecipientsNotAuthenticatedFailure>(),
        ),
      );
      expect(
        await limits.listActive(),
        isA<Err>().having(
          (r) => r.failure,
          'limit orders',
          isA<ExchangeNotAuthenticatedFailure>(),
        ),
      );
      credential = const Err(ExchangeCredentialReadFailure());
      expect(
        await funding.listInstitutions(jurisdiction: Jurisdiction.canada),
        isA<Err>().having(
          (r) => r.failure,
          'funding unavailable',
          isA<ExchangeUnexpectedFailure>(),
        ),
      );
      expect(
        await recipients.listRecipients(isTestnet: true),
        isA<Err>().having(
          (r) => r.failure,
          'recipients unavailable',
          isA<RecipientsLoadFailure>(),
        ),
      );
      expect(
        await limits.listActive(),
        isA<Err>().having(
          (r) => r.failure,
          'limit orders unavailable',
          isA<ExchangeLimitOrderFailure>().having(
            (failure) => failure.problem,
            'problem',
            ExchangeLimitOrderProblem.load,
          ),
        ),
      );
    },
  );
}
