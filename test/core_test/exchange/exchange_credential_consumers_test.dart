import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/fund_exchange/adapters/funding_gateway/bullbitcoin_api_funding_gateway.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:bb_mobile/features/fund_exchange/domain/primitives/funding_jurisdiction.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/gateways/bullbitcoin_api_recipients_gateway.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/limit_orders/data/datasources/limit_orders_api_datasource.dart';
import 'package:bb_mobile/features/limit_orders/data/limit_order_repository_impl.dart';
import 'package:bb_mobile/features/limit_orders/domain/limit_orders_failure.dart';
import 'dart:typed_data';

import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/exchange_support_chat_datasource.dart';
import 'package:bb_mobile/core/exchange/data/http/exchange_authentication_interceptor.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_order_repository_impl.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_support_chat_repository_impl.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_user_repository_impl.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_api_key_failure.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_order_failure.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_support_chat_failure.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_user_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

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

class _Settings extends Fake implements SettingsRepository {
  @override
  Future<SettingsEntity> fetch() async => const SettingsEntity(
    environment: Environment.testnet,
    bitcoinUnit: BitcoinUnit.btc,
    currencyCode: 'CAD',
  );
}

void main() {
  late Dio dio;
  late _NoNetwork network;
  late ExchangeUserRepositoryImpl user;
  late ExchangeSupportChatRepositoryImpl support;
  late ExchangeOrderRepositoryImpl orders;
  Result<String?, ExchangeApiKeyFailure> credential = const Ok(null);

  setUp(() {
    credential = const Ok(null);
    network = _NoNetwork();
    dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
      ..httpClientAdapter = network;
    addExchangeAuthentication(dio, () async => credential);
    final api = BullbitcoinApiDatasource(bullbitcoinApiHttpClient: dio);
    user = ExchangeUserRepositoryImpl(bullbitcoinApiDatasource: api);
    support = ExchangeSupportChatRepositoryImpl(
      datasource: ExchangeSupportChatDatasource(bullbitcoinApiHttpClient: dio),
      bullbitcoinApiDatasource: api,
    );
    orders = ExchangeOrderRepositoryImpl(
      bullbitcoinApiDatasource: api,
      isTestnet: true,
    );
  });
  tearDown(() {
    expect(network.sends, 0);
    dio.close();
  });

  test(
    'no session yields contextual empty results or authentication failures',
    () async {
      final profile = await user.getUserSummary();
      expect(
        profile,
        isA<Err>().having(
          (r) => r.failure,
          'profile',
          isA<ExchangeUserNotAuthenticatedFailure>(),
        ),
      );
      final announcements = await user.listAnnouncements();
      expect(
        announcements,
        isA<Ok>().having((r) => r.value, 'announcements', isEmpty),
      );
      final messages = await support.getMessages();
      expect(
        messages,
        isA<Err>().having(
          (r) => r.failure,
          'chat',
          isA<NotAuthenticatedFailure>(),
        ),
      );
      final history = await orders.getOrders();
      expect(history, isA<Ok>().having((r) => r.value, 'history', isEmpty));
      await expectLater(
        orders.getOrder('order'),
        throwsA(isA<ApiKeyException>()),
      );
    },
  );

  test(
    'storage failure is not presented as logout or empty account history',
    () async {
      credential = const Err(ExchangeApiKeyReadFailure());
      expect(
        await user.getUserSummary(),
        isA<Err>().having(
          (r) => r.failure,
          'profile',
          isA<ExchangeUserSummaryUnavailableFailure>(),
        ),
      );
      expect(
        await user.listAnnouncements(),
        isA<Err>().having(
          (r) => r.failure,
          'announcements',
          isA<ExchangeUserAnnouncementsUnavailableFailure>(),
        ),
      );
      expect(
        await support.getMessages(),
        isA<Err>().having((r) => r.failure, 'chat', isA<LoadMessagesFailure>()),
      );
      expect(
        await orders.getOrders(),
        isA<Err>().having(
          (r) => r.failure,
          'history',
          isA<ExchangeOrderCredentialFailure>(),
        ),
      );
      expect(
        await orders.getOrderByTxId('tx'),
        isA<Err>().having(
          (r) => r.failure,
          'lookup',
          isA<ExchangeOrderCredentialFailure>(),
        ),
      );
    },
  );
  test(
    'shared Dio features distinguish missing credentials from read failures',
    () async {
      final funding = BullBitcoinApiFundingGateway(authenticatedApiClient: dio);
      final recipients = BullbitcoinApiRecipientsGateway(
        authenticatedApiClient: dio,
      );
      final api = LimitOrdersApiDatasource(authenticatedApiClient: dio);
      final limits = LimitOrderRepositoryImpl(api, api, _Settings());
      expect(
        await funding.listInstitutions(
          jurisdiction: FundingJurisdiction.canada,
        ),
        isA<Err>().having(
          (r) => r.failure,
          'funding',
          isA<FundExchangeNotAuthenticatedFailure>(),
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
          isA<LimitOrdersAccountUnavailableFailure>(),
        ),
      );
      credential = const Err(ExchangeApiKeyReadFailure());
      expect(
        await funding.listInstitutions(
          jurisdiction: FundingJurisdiction.canada,
        ),
        isA<Err>().having(
          (r) => r.failure,
          'funding unavailable',
          isA<FundExchangeUnexpectedFailure>(),
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
          isA<LimitOrdersLoadFailure>(),
        ),
      );
    },
  );
}
