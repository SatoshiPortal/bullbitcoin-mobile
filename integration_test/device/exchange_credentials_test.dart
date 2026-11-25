import 'package:exchange/setup.dart';

import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter/widgets.dart';
import 'package:bbx_api/bbx_api.dart'
    show Bbx, BbxCredentialUnavailableFailure, BbxFailure;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('native exchange credential probes', () {
    late InMemoryExchangeCredentialStorage storage;
    late ExchangeCredentials repository;
    Future<void> storeCredential(String value, {required bool isTestnet}) =>
        storage.writeApiKeyRecord(value, isTestnet: isTestnet);

    var completedProbes = 0;
    // The production credential lives in the app's encrypted Exchange store,
    // which a standalone probe cannot open, so no live preprod probe exists.
    const livePreprod = false;
    const expectedProbes = 6;

    setUp(() {
      storage = InMemoryExchangeCredentialStorage();
      repository = ExchangeCredentials.open(storage);
    });
    tearDown(() => completedProbes++);
    tearDownAll(() {
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
      'stored credentials preserve absence and inactive session semantics',
      (tester) async {
        final absent = await repository.readActiveApiKey(isTestnet: true);
        expect(
          absent is Ok<String?, ExchangeFailure> && absent.value == null,
          isTrue,
        );
        await storeCredential(
          jsonEncode({'key': 'synthetic', 'isActive': false}),
          isTestnet: true,
        );
        final inactive = await repository.readActiveApiKey(isTestnet: true);
        expect(
          inactive is Ok<String?, ExchangeFailure> && inactive.value == null,
          isTrue,
        );
      },
    );

    testWidgets('stored credentials reread rotation and isolate environments', (
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
        first is Ok<String?, ExchangeFailure> &&
            first.value == 'test-synthetic',
        isTrue,
      );
      await storeCredential(
        jsonEncode({'key': 'rotated-synthetic', 'isActive': true}),
        isTestnet: true,
      );
      final rotated = await repository.readActiveApiKey(isTestnet: true);
      expect(
        rotated is Ok<String?, ExchangeFailure> &&
            rotated.value == 'rotated-synthetic',
        isTrue,
      );
      expect(
        await repository.deleteApiKey(isTestnet: true),
        isA<Ok<void, ExchangeFailure>>(),
      );
      final revoked = await repository.readActiveApiKey(isTestnet: true);
      expect(
        revoked is Ok<String?, ExchangeFailure> && revoked.value == null,
        isTrue,
      );
      final mainnet = await repository.readActiveApiKey(isTestnet: false);
      expect(
        mainnet is Ok<String?, ExchangeFailure> &&
            mainnet.value == 'main-synthetic',
        isTrue,
      );
    });

    testWidgets('authentication does not require account metadata', (
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
        value is Ok<String?, ExchangeFailure> && value.value == 'synthetic',
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
        invalid is Err<String?, ExchangeFailure> &&
            invalid.failure is ExchangeApiKeyInvalidFailure,
        isTrue,
      );
      expect(storage.entries['testnet'] == corrupt, isTrue);
      storage.scripted.add(Exception());
      final unavailable = await repository.readActiveApiKey(isTestnet: true);
      expect(
        unavailable is Err<String?, ExchangeFailure> &&
            unavailable.failure is ExchangeCredentialReadFailure,
        isTrue,
      );
      expect(storage.entries['testnet'] == corrupt, isTrue);
    });
    testWidgets(
      'HTTP and WebSocket authentication reread the same credential',
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
            request.response.write(
              jsonEncode({
                'jsonrpc': '2.0',
                'result': {'success': true},
              }),
            );
            await request.response.close();
          }
        });
        final baseUrl = 'http://127.0.0.1:${server.port}';
        // The app's credential read as the package's own failure family, as
        // the composition root wires it.
        Future<Result<String?, BbxFailure>> credential() async =>
            switch (await repository.readActiveApiKey(isTestnet: true)) {
              Ok(:final value) => Ok<String?, BbxFailure>(value),
              Err() => const Err<String?, BbxFailure>(
                BbxCredentialUnavailableFailure(),
              ),
            };
        final api = Bbx.open(endpoint: baseUrl, readActiveApiKey: credential);
        final exchange = Exchange.open(
          mainnetEndpoint: Uri.parse(baseUrl),
          testnetEndpoint: Uri.parse(baseUrl),
          readSession: () async => const Err(ExchangeUnexpectedFailure()),
          notifications: (readKey: repository.readActiveApiKey),
        );
        addTearDown(() async {
          await exchange.close();
          api.dispose();
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
        // A harmless authenticated call: the stored credential must reach the
        // server on this request.
        final probeResult = await api.users.registerResponsibilityConsent();
        expect(
          probeResult is Ok<bool, BbxFailure> && probeResult.value,
          isTrue,
          reason: 'the HTTP probe must carry the stored credential',
        );
        await storeCredential(
          jsonEncode({'key': 'socket-synthetic', 'isActive': true}),
          isTestnet: true,
        );
        expect(
          await exchange.connectNotifications(ExchangeEnvironment.testnet),
          isA<Ok>(),
        );
        exchange.disconnectNotifications();
        storage.scripted.add(Exception());
        expect(
          await api.users.registerResponsibilityConsent(),
          isA<Err>().having(
            (r) => r.failure,
            'storage refusal',
            isA<BbxCredentialUnavailableFailure>(),
          ),
          reason: 'an unreadable credential must not reach the network',
        );
        expect(keys, ['http-synthetic', 'socket-synthetic']);
      },
    );

    testWidgets(
      'the real WebView result crosses the production authentication graph',
      (tester) async {
        String? preference;
        final access = ExchangeAccessLifecycle.open(
          apiKeyRepository: repository,
          readEnvironment: () async => true,
          platformAllowed: () async => true,
          disconnectNotifications: () async {},
          clearCookies: () async {},
          readPreference: () async => preference,
          writePreference: (value) async {
            preference = value;
            return true;
          },
        );
        expect(await access.enable(), isA<Ok>());
        final exchange = Exchange.open(
          mainnetEndpoint: Uri.parse(ExchangeDefaults.bbApiUrl),
          testnetEndpoint: Uri.parse(ExchangeDefaults.bbApiTestUrl),
          readSession: () async => fail('unexpected Exchange API request'),
          access: access,
          webAuthEndpoints: (
            mainnet: Uri.parse(ExchangeDefaults.bbAuthUrl),
            testnet: Uri.parse(ExchangeDefaults.bbAuthTestUrl),
          ),
        );
        addTearDown(exchange.close);
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
        final result = await exchange.authenticateWebSession(
          isTestnet: true,
          isCurrent: () => true,
          evaluateJavaScript: (script) async {
            final ready = await controller.runJavaScriptReturningResult(
              'window.__credentialProbeMockReady === true',
            );
            if (ready != true && ready != 'true') {
              throw StateError('Synthetic XHR is not installed');
            }
            return controller.runJavaScriptReturningResult(script);
          },
        );
        expect(
          result is Ok,
          isTrue,
          reason: 'native WebView response must decode and persist',
        );
        final credential = await repository.readActiveApiKey(isTestnet: true);
        expect(
          credential is Ok<String?, ExchangeFailure> &&
              credential.value == 'webview-synthetic',
          isTrue,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });
}
