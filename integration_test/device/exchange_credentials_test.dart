import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core/exchange/data/exchange_api_key_repository_impl.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_api_key_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_api_key_repository.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/exchange/data/datasources/exchange_notification_datasource.dart';
import 'package:bb_mobile/core/exchange/data/http/exchange_authentication_interceptor.dart';
import 'package:bb_mobile/core/exchange/data/exchange_authentication.dart';
import 'package:bb_mobile/features/exchange/exchange_core_locator.dart'
    as core_exchange;
import 'package:bb_mobile/features/exchange/exchange_locator.dart'
    as feature_exchange;
import 'package:bb_mobile/features/exchange/domain/usecases/complete_exchange_authentication_usecase.dart';
import 'package:bb_mobile/features/recipients/data/bbx_api_recipients_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:bbx_api/bbx_api.dart' show BbxApiClient;
import 'package:dio/dio.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('native exchange credential probes', () {
    final locator = GetIt.asNewInstance();
    late ExchangeKeychain storage;
    late ExchangeKeychainProbe probe;
    late ExchangeApiKeyRepositoryImpl repository;
    Future<void> storeCredential(
      String value, {
      required bool isTestnet,
    }) async {
      expect(
        await storage.write(value, isTestnet: isTestnet) is Ok,
        isTrue,
        reason: 'synthetic credential must be persisted',
      );
    }

    var completedProbes = 0;
    const livePreprod = bool.fromEnvironment('TEST_EXCHANGE_LIVE');
    const expectedProbes = livePreprod ? 7 : 6;

    // Register every test synchronously before platform initialization can yield.
    setUpAll(() async {
      final secrets = Secrets(
        scratchDirectory: () async => Directory.systemTemp.path,
      );
      locator.registerSingleton<Secrets>(secrets);
      probe = ExchangeKeychainProbe()..install();
      storage = secrets.exchangeKeychain;
      repository = ExchangeApiKeyRepositoryImpl(secureStorage: storage);
    });

    setUp(() async {
      probe.refuseReads = false;
      probe.install();
      for (final isTestnet in [false, true]) {
        expect(await storage.delete(isTestnet: isTestnet) is Ok, isTrue);
      }
    });
    tearDown(() async {
      probe.refuseReads = false;
      await probe.clearWrittenProbeKeys();
      completedProbes++;
    });
    tearDownAll(() async {
      try {
        await probe.clearWrittenProbeKeys();
      } finally {
        probe.restore();
        await locator.reset();
      }
      expect(completedProbes, expectedProbes);
      // Fixture cleanup alone must not count as an executed widget test.
      expect(binding.results, hasLength(expectedProbes));
      expect(binding.results.values, everyElement('success'));
      binding.reportData = {
        'completedProbes': completedProbes,
        'expectedProbes': expectedProbes,
        'livePreprodEnabled': livePreprod,
      };
    });

    testWidgets(
      'native storage preserves absence and inactive session semantics',
      (tester) async {
        final absent = await repository.readActiveApiKey(isTestnet: true);
        expect(
          absent is Ok<String?, ExchangeApiKeyFailure> && absent.value == null,
          isTrue,
        );
        await storeCredential(
          jsonEncode({'key': 'synthetic', 'isActive': false}),
          isTestnet: true,
        );
        final inactive = await repository.readActiveApiKey(isTestnet: true);
        expect(
          inactive is Ok<String?, ExchangeApiKeyFailure> &&
              inactive.value == null,
          isTrue,
        );
      },
    );

    testWidgets('native storage rereads rotation and isolates environments', (
      tester,
    ) async {
      await storeCredential(
        jsonEncode({'key': 'main-synthetic', 'isActive': true}),
        isTestnet: false,
      );
      await storeCredential(
        jsonEncode({'key': 'test-synthetic', 'isActive': true}),
        isTestnet: true,
      );
      final first = await repository.readActiveApiKey(isTestnet: true);
      expect(
        first is Ok<String?, ExchangeApiKeyFailure> &&
            first.value == 'test-synthetic',
        isTrue,
      );
      await storeCredential(
        jsonEncode({'key': 'rotated-synthetic', 'isActive': true}),
        isTestnet: true,
      );
      final rotated = await repository.readActiveApiKey(isTestnet: true);
      expect(
        rotated is Ok<String?, ExchangeApiKeyFailure> &&
            rotated.value == 'rotated-synthetic',
        isTrue,
      );
      expect(
        await repository.deleteApiKey(isTestnet: true),
        isA<Ok<void, ExchangeApiKeyFailure>>(),
      );
      final revoked = await repository.readActiveApiKey(isTestnet: true);
      expect(
        revoked is Ok<String?, ExchangeApiKeyFailure> && revoked.value == null,
        isTrue,
      );
      final mainnet = await repository.readActiveApiKey(isTestnet: false);
      expect(
        mainnet is Ok<String?, ExchangeApiKeyFailure> &&
            mainnet.value == 'main-synthetic',
        isTrue,
      );
    });

    testWidgets('native authentication does not require account metadata', (
      tester,
    ) async {
      await storeCredential(
        jsonEncode({
          'key': 'synthetic',
          'isActive': true,
          'createdAt': 'invalid',
        }),
        isTestnet: true,
      );
      final value = await repository.readActiveApiKey(isTestnet: true);
      expect(
        value is Ok<String?, ExchangeApiKeyFailure> &&
            value.value == 'synthetic',
        isTrue,
      );
    });

    testWidgets('corruption and simulated storage refusal are not logout', (
      tester,
    ) async {
      const corrupt = '{"key":"synthetic", broken';
      await storeCredential(corrupt, isTestnet: true);
      final invalid = await repository.readActiveApiKey(isTestnet: true);
      expect(
        invalid is Err<String?, ExchangeApiKeyFailure> &&
            invalid.failure is ExchangeApiKeyInvalidFailure,
        isTrue,
      );
      expect(
        (await storage.read(
              isTestnet: true,
            ) as Ok<String?, SecretFailure>).value ==
            corrupt,
        isTrue,
      );
      probe.refuseReads = true;
      final unavailable = await repository.readActiveApiKey(isTestnet: true);
      expect(
        unavailable is Err<String?, ExchangeApiKeyFailure> &&
            unavailable.failure is ExchangeApiKeyReadFailure,
        isTrue,
      );
      probe.refuseReads = false;
      expect(
        (await storage.read(
              isTestnet: true,
            ) as Ok<String?, SecretFailure>).value ==
            corrupt,
        isTrue,
      );
    });
    testWidgets(
      'native HTTP and WebSocket authentication reread the same credential',
      (tester) async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final keys = <String?>[];
        final sockets = <WebSocket>[];
        final subscription = server.listen((request) async {
          keys.add(request.headers.value('X-API-Key'));
          if (WebSocketTransformer.isUpgradeRequest(request)) {
            final socket = await WebSocketTransformer.upgrade(request);
            sockets.add(socket);
            socket.listen((_) {});
          } else {
            request.response.headers.contentType = ContentType.json;
            request.response.write('{}');
            await request.response.close();
          }
        });
        final baseUrl = 'http://127.0.0.1:${server.port}';
        final client = Dio(BaseOptions(baseUrl: baseUrl));
        addExchangeAuthentication(
          client,
          () => repository.readActiveApiKey(isTestnet: true),
        );
        final socket = ExchangeNotificationDatasource(
          baseUrl: baseUrl,
          readApiKey: () => repository.readActiveApiKey(isTestnet: true),
        );
        addTearDown(() async {
          socket.dispose();
          client.close(force: true);
          for (final connection in sockets) {
            await connection.close();
          }
          await subscription.cancel();
          await server.close(force: true);
        });
        await storeCredential(
          jsonEncode({'key': 'http-synthetic', 'isActive': true}),
          isTestnet: true,
        );
        await client.get<void>('/probe');
        await storeCredential(
          jsonEncode({'key': 'socket-synthetic', 'isActive': true}),
          isTestnet: true,
        );
        await socket.connect();
        expect(socket.isConnected, isTrue);
        socket.disconnect();
        probe.refuseReads = true;
        await expectLater(
          client.get<void>('/probe'),
          throwsA(
            isA<DioException>().having(
              (e) => exchangeAuthenticationException(e)?.failure,
              'storage refusal',
              isA<ExchangeApiKeyReadFailure>(),
            ),
          ),
        );
        expect(keys, ['http-synthetic', 'socket-synthetic']);
      },
    );

    testWidgets(
      'the real WebView result crosses the production authentication graph',
      (tester) async {
        final graph = GetIt.asNewInstance();
        graph.registerSingleton<ExchangeApiKeyRepository>(repository);
        feature_exchange.ExchangeLocator.registerUsecases(graph);
        addTearDown(graph.reset);
        final loaded = Completer<void>();
        final controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageFinished: (_) {
                if (!loaded.isCompleted) loaded.complete();
              },
            ),
          );
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: WebViewWidget(controller: controller),
          ),
        );
        const payload = {
          'apiKey': {
            'id': 'native-id',
            'key': 'webview-synthetic',
            'name': 'native-test',
            'userId': 'synthetic-user',
            'isActive': true,
            'createdAt': 0,
            'updatedAt': 0,
          },
        };
        final response = jsonEncode(jsonEncode(payload));
        await controller.loadHtmlString('''<!doctype html><html><body><script>
      window.XMLHttpRequest = function() {
        this.status = 200;
        this.responseText = $response;
        this.open = function() {};
        this.setRequestHeader = function() {};
        this.send = function() {};
      };
      window.__credentialProbeMockReady = true;
      </script></body></html>''');
        await loaded.future.timeout(const Duration(seconds: 20));
        final operation = graph<CompleteExchangeAuthenticationUsecase>(
          param1: (String script) async {
            final ready = await controller.runJavaScriptReturningResult(
              'window.__credentialProbeMockReady === true',
            );
            if (ready != true && ready != 'true') {
              throw StateError('Synthetic XHR is not installed');
            }
            return controller.runJavaScriptReturningResult(script);
          },
          param2: (isTestnet: true, isOpen: () => true),
        );
        final result = await operation.execute(isCurrent: () => true);
        expect(
          result is Ok,
          isTrue,
          reason: 'native WebView response must decode and persist',
        );
        final credential = await repository.readActiveApiKey(isTestnet: true);
        expect(
          credential is Ok<String?, ExchangeApiKeyFailure> &&
              credential.value == 'webview-synthetic',
          isTrue,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    if (livePreprod) {
      testWidgets(
        'read-only preprod calls retain the existing testnet session',
        (tester) async {
          probe.restore();
          try {
            core_exchange.ExchangeLocator.registerDatasources(locator);
            core_exchange.ExchangeLocator.registerRepositories(locator);
            final credentials = locator<ExchangeApiKeyRepository>();
            final before = await credentials.readActiveApiKey(isTestnet: true);
            final authenticated =
                before is Ok<String?, ExchangeApiKeyFailure> &&
                before.value != null;
            expect(
              authenticated,
              isTrue,
              reason: 'requires an existing preprod session',
            );
            final account = await locator<ExchangeUserRepository>(
              instanceName: 'testnetExchangeUserRepository',
            ).getUserSummary();
            expect(
              account is Ok,
              isTrue,
              reason: 'preprod account read must succeed',
            );
            final orders = await locator<ExchangeOrderRepository>(
              instanceName: 'testnetExchangeOrderRepository',
            ).getOrders();
            expect(
              orders is Ok,
              isTrue,
              reason: 'preprod history read must succeed',
            );
            final recipients = await BbxApiRecipientsRepository(
              api: locator<BbxApiClient>(instanceName: 'testnetBbxApiClient'),
            ).listRecipients(isTestnet: true);
            expect(
              recipients is Ok,
              isTrue,
              reason: 'preprod recipients read must succeed',
            );
            final after = await credentials.readActiveApiKey(isTestnet: true);
            final unchanged = switch ((before, after)) {
              (Ok(value: final original), Ok(value: final current)) =>
                original == current,
              _ => false,
            };
            expect(
              unchanged,
              isTrue,
              reason: 'read-only probes must preserve the credential',
            );
            expect(
              after is Ok<String?, ExchangeApiKeyFailure> &&
                  after.value != null,
              isTrue,
              reason: 'read-only probes must not clear the existing session',
            );
          } finally {
            probe.install();
          }
        },
      );
    }
  });
}
