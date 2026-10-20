import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/exchange_notification_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/api_key_model.dart';
import 'package:bb_mobile/core/exchange/data/services/exchange_notification_service.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/foreground_lifecycle.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_listener.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';

class _Keys extends Mock implements BullbitcoinApiKeyDatasource {}

class _Settings extends Mock implements SettingsRepository {}

class _Cubit extends MockCubit<ExchangeState> implements ExchangeCubit {}

int _harnessIndex = 0;

const _syntheticKey = 'pixel5-notifications-only';
const _summary = UserSummary(
  userNumber: 1,
  groups: [],
  profile: UserProfile(firstName: 'Device', lastName: 'Test'),
  email: 'device@example.invalid',
  balances: [],
  dca: UserDca(isActive: false),
  autoBuy: UserAutoBuy(isActive: false, addresses: UserAutoBuyAddresses()),
);

// Markers are consumed by a host driving the reserved device over ADB.
void _mark(String message) {
  // ignore: avoid_print
  print(message);
}

Future<void> _until(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed > timeout) fail('Device condition timed out');
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}

class _Counts {
  int requests = 0;
  int accepted = 0;
  int closed = 0;
  int refreshes = 0;
  bool authenticated = true;
  Environment environment = Environment.mainnet;
  ExchangeState state = const ExchangeState(userSummary: _summary);
  final keyReads = <DateTime>[];
  final firstRequest = Completer<void>();
  Completer<ExchangeApiKeyModel?>? pendingKey;
  bool throwKeyError = false;
}

class _Harness {
  final HttpServer server;
  final List<WebSocket> sockets;
  final _Counts counts;
  final ForegroundLifecycle foreground;
  final ExchangeNotificationDatasource mainnet;
  final ExchangeNotificationDatasource testnet;
  final ExchangeNotificationService service;
  final _Cubit cubit;
  final StreamController<ExchangeState> states;

  _Harness({
    required this.server,
    required this.sockets,
    required this.counts,
    required this.foreground,
    required this.mainnet,
    required this.testnet,
    required this.service,
    required this.cubit,
    required this.states,
  });

  static Future<_Harness> mount(
    WidgetTester tester,
    IntegrationTestWidgetsFlutterBinding binding, {
    String? baseUrl,
    bool holdFirst = false,
    bool holdAll = false,
    bool rejectUpgrade = false,
  }) async {
    // Flutter resets lifecycleState between widget tests. Obtain fresh native
    // events instead of manufacturing a resumed state in the test binding.
    final index = ++_harnessIndex;
    _mark('WS_INIT_READY:$index');
    await _until(
      () => binding.lifecycleState == AppLifecycleState.paused,
      timeout: const Duration(seconds: 45),
    );
    _mark('WS_INIT_GATED:$index');
    await _until(
      () => binding.lifecycleState == AppLifecycleState.resumed,
      timeout: const Duration(seconds: 45),
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <WebSocket>[];
    final counts = _Counts();
    server.listen((request) async {
      counts.requests++;
      if (!counts.firstRequest.isCompleted) counts.firstRequest.complete();
      expect(request.headers.value('X-API-Key'), _syntheticKey);
      if (rejectUpgrade) {
        request.response.statusCode = HttpStatus.serviceUnavailable;
        await request.response.close();
        return;
      }
      if (holdAll || (holdFirst && counts.requests == 1)) return;
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      counts.accepted++;
      socket.listen((_) {}, onDone: () => counts.closed++);
    });
    final foreground = ForegroundLifecycle(binding: binding);
    final keys = _Keys();
    for (final isTestnet in [false, true]) {
      when(() => keys.get(isTestnet: isTestnet)).thenAnswer((_) async {
        counts.keyReads.add(DateTime.now());
        if (counts.throwKeyError) throw StateError('synthetic credential bug');
        final pending = counts.pendingKey;
        if (pending != null) return pending.future;
        return counts.authenticated ? key() : null;
      });
    }
    final localUrl = 'http://127.0.0.1:${server.port}';
    final mainnet = ExchangeNotificationDatasource(
      baseUrl: baseUrl ?? localUrl,
      apiKeyDatasource: keys,
      isTestnet: false,
      isForeground: () => foreground.isForeground,
    );
    final testnet = ExchangeNotificationDatasource(
      baseUrl: '$localUrl/testnet',
      apiKeyDatasource: keys,
      isTestnet: true,
      isForeground: () => foreground.isForeground,
    );
    final settings = _Settings();
    when(() => settings.fetch()).thenAnswer(
      (_) async => SettingsEntity(
        environment: counts.environment,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
    final service = ExchangeNotificationService(
      mainnetDatasource: mainnet,
      testnetDatasource: testnet,
      settingsRepository: settings,
    );
    final states = StreamController<ExchangeState>.broadcast();
    final cubit = _Cubit();
    // Native lifecycle callbacks run outside testWidgets' error zone. Keep
    // socket creation and cancellation in the same zone: Dart futures cannot
    // deliver errors across error-zone boundaries, including HttpClient's
    // internal cancellation listeners. This also exposes failures to the test.
    final testZone = Zone.current;
    when(() => cubit.state).thenAnswer((_) => counts.state);
    when(() => cubit.stream).thenAnswer((_) => states.stream);
    when(
      () => cubit.connectWebSocket(),
    ).thenAnswer((_) => testZone.run(service.connect));
    when(
      () => cubit.reconnectWebSocket(),
    ).thenAnswer((_) => testZone.run(service.reconnect));
    when(
      () => cubit.disconnectWebSocket(),
    ).thenAnswer((_) => testZone.run(service.disconnect));
    when(() => cubit.fetchUserSummary()).thenAnswer((_) async {
      counts.refreshes++;
    });
    final harness = _Harness(
      server: server,
      sockets: sockets,
      counts: counts,
      foreground: foreground,
      mainnet: mainnet,
      testnet: testnet,
      service: service,
      cubit: cubit,
      states: states,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await harness.dispose();
    });
    await tester.pumpWidget(
      BlocProvider<ExchangeCubit>.value(
        value: cubit,
        child: const ExchangeListener(child: SizedBox()),
      ),
    );
    return harness;
  }

  static ExchangeApiKeyModel key() => ExchangeApiKeyModel(
    id: 'device-test',
    key: _syntheticKey,
    name: 'device-test',
    userId: 'device-test',
    isActive: true,
    createdAt: 0,
    updatedAt: 0,
  );

  Future<void> authenticate(bool authenticated) async {
    counts.authenticated = authenticated;
    counts.state = counts.state.copyWith(
      userSummary: authenticated ? _summary : null,
    );
    states.add(counts.state);
    // BlocListener consumes the stream without a rendered frame. Waiting for
    // pump() while Android is paused would stall until the host resumes it.
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> message({String type = 'balance'}) async {
    final next = service.messageStream.first;
    sockets.last.add('{"type":"$type"}');
    final received = await next.timeout(const Duration(seconds: 5));
    expect(received.kind.name, type);
  }

  Future<void> dispose() async {
    foreground.dispose();
    service.dispose();
    mainnet.dispose();
    testnet.dispose();
    await cubit.close();
    await states.close();
    for (final socket in sockets) {
      await socket.close();
    }
    await server.close(force: true);
  }
}

Future<void> _background(
  IntegrationTestWidgetsFlutterBinding binding,
  String id,
  String action,
  Future<void> Function() whileBackground,
) async {
  _mark('WS_CASE_READY:$id:$action');
  await _until(
    () => binding.lifecycleState == AppLifecycleState.paused,
    timeout: const Duration(seconds: 45),
  );
  await whileBackground();
  _mark('WS_CASE_GATED:$id');
  await _until(
    () => binding.lifecycleState == AppLifecycleState.resumed,
    timeout: const Duration(seconds: 45),
  );
}

Future<void> main() async {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('Android notification matrix', () {
    setUpAll(() {
      expect(
        const bool.fromEnvironment('WS_EXTERNAL_LIFECYCLE'),
        isTrue,
        reason: 'This matrix requires a host driving real Android events',
      );
    });
    setUp(() async {
      final directory = await Directory.systemTemp.createTemp('ws-device-');
      log = Logger.replace(directory: directory);
      await log.ensureLogsExist(writeDiagnosticContext: false);
    });
    tearDown(() async {
      await log.flush();
      final lines = await log.logsFile.readAsLines();
      expect(lines.where((line) => line.contains('\tSEVERE\t')), isEmpty);
      expect(lines.any((line) => line.contains(_syntheticKey)), isFalse);
      expect(lines.any((line) => line.contains('{"type":')), isFalse);
      _mark(
        'WS_LOG_OK severe=0 close_warnings='
        '${lines.where((line) => line.contains('WebSocket close failed')).length}',
      );
    });

    testWidgets('real notification shade preserves socket and messages', (
      tester,
    ) async {
      final h = await _Harness.mount(tester, binding);
      await h.service.connect();
      _mark('WS_FOCUS_READY:shade');
      await _until(() => binding.lifecycleState == AppLifecycleState.inactive);
      expect(h.mainnet.isConnected, isTrue);
      await h.message();
      _mark('WS_FOCUS_GATED:shade');
      await _until(() => binding.lifecycleState == AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(h.counts.accepted, 1);
      expect(h.counts.refreshes, 0);
      await h.message();
    });

    testWidgets('repeated Home and screen lock reconnect exactly once each', (
      tester,
    ) async {
      final h = await _Harness.mount(tester, binding);
      await h.service.connect();
      final actions = ['home', 'lock', 'home', 'lock'];
      for (var index = 0; index < actions.length; index++) {
        final accepted = h.counts.accepted;
        await _background(binding, 'cycle-$index', actions[index], () async {
          expect(h.mainnet.isConnected, isFalse);
          await _until(() => h.counts.closed == accepted);
          final reads = h.counts.keyReads.length;
          await h.service.reconnect();
          await Future<void>.delayed(const Duration(seconds: 6));
          expect(h.counts.keyReads, hasLength(reads));
          expect(h.counts.accepted, accepted);
        });
        await _until(() => h.mainnet.isConnected);
        expect(h.counts.accepted, accepted + 1);
        expect(h.counts.refreshes, index + 1);
        await h.message();
      }
    });

    testWidgets('background cancels a pending credential lookup', (
      tester,
    ) async {
      final h = await _Harness.mount(tester, binding);
      final pending = Completer<ExchangeApiKeyModel?>();
      h.counts.pendingKey = pending;
      final connecting = h.service.connect();
      await _until(() => h.counts.keyReads.length == 1);
      await _background(binding, 'credentials', 'home', () async {
        h.counts.pendingKey = null;
        pending.complete(_Harness.key());
        await connecting.timeout(const Duration(seconds: 5));
        expect(h.counts.requests, 0);
        expect(h.mainnet.isConnected, isFalse);
      });
      await _until(() => h.mainnet.isConnected);
      expect(h.counts.accepted, 1);
      await h.message();
    });

    testWidgets('background aborts a pending native upgrade', (tester) async {
      final h = await _Harness.mount(tester, binding, holdFirst: true);
      final connecting = h.service.connect();
      await h.counts.firstRequest.future.timeout(const Duration(seconds: 5));
      await _background(binding, 'upgrade', 'home', () async {
        await connecting.timeout(const Duration(seconds: 5));
        expect(h.mainnet.isConnected, isFalse);
        expect(h.counts.accepted, 0);
      });
      await _until(() => h.mainnet.isConnected);
      expect(h.counts.requests, 2);
      expect(h.counts.accepted, 1);
      await h.message();
    });

    testWidgets('logout and background login respect authentication', (
      tester,
    ) async {
      final h = await _Harness.mount(tester, binding);
      await h.service.connect();
      await h.authenticate(false);
      await _until(() => h.counts.closed == 1);
      await _background(binding, 'signed-out', 'home', () async {
        expect(h.mainnet.isConnected, isFalse);
      });
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(h.counts.accepted, 1);
      expect(h.counts.refreshes, 0);
      await _background(binding, 'authentication', 'home', () async {
        final reads = h.counts.keyReads.length;
        await h.authenticate(true);
        await Future<void>.delayed(const Duration(seconds: 1));
        expect(h.counts.keyReads, hasLength(reads));
        expect(h.counts.accepted, 1);
      });
      await _until(() => h.mainnet.isConnected);
      expect(h.counts.accepted, 2);
      await h.message();
    });

    testWidgets('peer close retries once and disposal stops retries', (
      tester,
    ) async {
      final h = await _Harness.mount(tester, binding);
      await h.service.connect();
      await h.sockets.single.close();
      await _until(() => !h.mainnet.isConnected);
      await _until(() => h.mainnet.isConnected);
      expect(h.counts.accepted, 2);
      await h.message();
      await h.sockets.last.close();
      await _until(() => !h.mainnet.isConnected);
      h.service.disconnect();
      final reads = h.counts.keyReads.length;
      await Future<void>.delayed(const Duration(seconds: 6));
      expect(h.counts.accepted, 2);
      expect(h.counts.keyReads, hasLength(reads));
    });

    testWidgets(
      'network environment switch closes the previous native socket',
      (tester) async {
        final h = await _Harness.mount(tester, binding);
        await h.service.connect();
        await h.message();
        h.counts.environment = Environment.testnet;
        await h.service.connect();
        await _until(() => h.counts.closed == 1);
        expect(h.mainnet.isConnected, isFalse);
        expect(h.testnet.isConnected, isTrue);
        expect(h.counts.accepted, 2);
        await h.message(type: 'order');
      },
    );

    testWidgets(
      'programmer error propagates and permits a new native connection',
      (tester) async {
        final h = await _Harness.mount(tester, binding);
        h.counts.throwKeyError = true;
        await expectLater(h.service.connect(), throwsStateError);
        h.counts.throwKeyError = false;
        await h.service.connect();
        expect(h.mainnet.isConnected, isTrue);
        expect(h.counts.accepted, 1);
        await h.message();
      },
    );

    testWidgets('an unavailable upgrade does not create a retry loop', (
      tester,
    ) async {
      final h = await _Harness.mount(tester, binding, rejectUpgrade: true);
      await h.service.connect();
      expect(h.mainnet.isConnected, isFalse);
      await Future<void>.delayed(const Duration(seconds: 6));
      expect(h.counts.requests, 1);
      expect(h.counts.keyReads, hasLength(1));
    });

    testWidgets(
      'native upgrade times out and a cancelled retry stays cancelled',
      (tester) async {
        final h = await _Harness.mount(tester, binding, holdAll: true);
        final watch = Stopwatch()..start();
        await h.service.connect().timeout(const Duration(seconds: 25));
        expect(
          watch.elapsed,
          greaterThanOrEqualTo(const Duration(seconds: 14)),
        );
        expect(h.mainnet.isConnected, isFalse);
        expect(h.counts.requests, 1);
        await _until(() => h.counts.requests == 2);
        h.service.disconnect();
        await Future<void>.delayed(const Duration(seconds: 6));
        expect(h.counts.requests, 2);
      },
    );

    testWidgets('real DNS failures back off and stop while backgrounded', (
      tester,
    ) async {
      final h = await _Harness.mount(
        tester,
        binding,
        baseUrl: 'https://bull-notifications-test.invalid',
      );
      await h.service.connect();
      expect(h.mainnet.isConnected, isFalse);
      await _until(
        () => h.counts.keyReads.length >= 3,
        timeout: const Duration(seconds: 60),
      );
      expect(h.counts.keyReads, hasLength(3));
      expect(
        h.counts.keyReads[1].difference(h.counts.keyReads[0]),
        greaterThanOrEqualTo(const Duration(seconds: 5)),
      );
      expect(
        h.counts.keyReads[2].difference(h.counts.keyReads[1]),
        greaterThanOrEqualTo(const Duration(seconds: 10)),
      );
      await _background(binding, 'dns', 'home', () async {
        final reads = h.counts.keyReads.length;
        await Future<void>.delayed(const Duration(seconds: 22));
        expect(h.counts.keyReads, hasLength(reads));
      });
      await _until(() => h.counts.keyReads.length == 4);
      h.service.disconnect();
      await log.flush();
      final lines = await log.logsFile.readAsLines();
      expect(lines.any((line) => line.contains('Failed host lookup')), isTrue);
      _mark('WS_DNS_BACKOFF_OK reads=${h.counts.keyReads.length}');
    });

    testWidgets('real Wi-Fi outage recovers without duplicate streams', (
      tester,
    ) async {
      const networkUrl = String.fromEnvironment('WS_NETWORK_BASE_URL');
      expect(
        networkUrl,
        isNotEmpty,
        reason: 'Pass the controlled LAN server URL',
      );
      final h = await _Harness.mount(tester, binding, baseUrl: networkUrl);
      final messages = <String>[];
      final subscription = h.service.messageStream.listen(
        (m) => messages.add(m.kind.name),
      );
      addTearDown(subscription.cancel);
      await h.service.connect();
      await _until(() => messages.length == 1);
      _mark('WS_NETWORK_READY');
      await _until(
        () => !h.mainnet.isConnected,
        timeout: const Duration(seconds: 90),
      );
      await _until(
        () => h.counts.keyReads.length >= 2,
        timeout: const Duration(seconds: 35),
      );
      _mark('WS_NETWORK_RESTORE');
      await _until(
        () => h.mainnet.isConnected,
        timeout: const Duration(seconds: 90),
      );
      await _until(() => messages.length == 2);
      await Future<void>.delayed(const Duration(seconds: 3));
      expect(messages, ['balance', 'balance']);
      _mark(
        'WS_NETWORK_OK reads=${h.counts.keyReads.length} messages=${messages.length}',
      );
    });
  });
}
