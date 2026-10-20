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

const _summary = UserSummary(
  userNumber: 1,
  groups: [],
  profile: UserProfile(firstName: 'Integration', lastName: 'Test'),
  email: 'integration@example.invalid',
  balances: [],
  dca: UserDca(isActive: false),
  autoBuy: UserAutoBuy(isActive: false, addresses: UserAutoBuyAddresses()),
);

Future<void> _waitFor(bool Function() condition) async {
  final elapsed = Stopwatch()..start();
  while (!condition()) {
    if (elapsed.elapsed > const Duration(seconds: 5)) {
      fail('Timed out waiting for the local notification socket');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

// Standalone device suite: the root integration aggregator initializes a
// different test binding and the production app. This suite uses neither app
// storage nor accounts. By default it drives Flutter lifecycle events. With
// WS_EXTERNAL_LIFECYCLE=true, press Home at WS_ANDROID_READY_BACKGROUND and
// reopen the test activity at WS_ANDROID_BACKGROUND_GATED to test OS events.
Future<void> main() async {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  log = Logger.replace(directory: Directory.systemTemp);
  late _Keys keys;

  setUp(() {
    keys = _Keys();
    // Synthetic credentials: never read the installed app's exchange account.
    when(() => keys.get(isTestnet: false)).thenAnswer(
      (_) async => ExchangeApiKeyModel(
        id: 'integration-test',
        key: 'integration-test-only',
        name: 'integration-test',
        userId: 'integration-test',
        isActive: true,
        createdAt: 0,
        updatedAt: 0,
      ),
    );
  });

  testWidgets('native socket stops in background and resumes once', (
    tester,
  ) async {
    await _waitFor(() => binding.lifecycleState == AppLifecycleState.resumed);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <WebSocket>[];
    var accepted = 0;
    var closed = 0;
    server.listen((request) async {
      expect(request.uri.path, '/ak/api-commcenter');
      expect(request.headers.value('X-API-Key'), 'integration-test-only');
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      accepted++;
      socket.listen((_) {}, onDone: () => closed++);
    });
    final foreground = ForegroundLifecycle(binding: binding);
    final datasource = ExchangeNotificationDatasource(
      baseUrl: 'http://127.0.0.1:${server.port}',
      apiKeyDatasource: keys,
      isTestnet: false,
      isForeground: () => foreground.isForeground,
    );
    final settings = _Settings();
    when(() => settings.fetch()).thenAnswer(
      (_) async => SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
    final service = ExchangeNotificationService(
      mainnetDatasource: datasource,
      testnetDatasource: ExchangeNotificationDatasource(
        baseUrl: 'http://127.0.0.1:${server.port}',
        apiKeyDatasource: keys,
        isTestnet: true,
      ),
      settingsRepository: settings,
    );
    final cubit = _Cubit();
    when(
      () => cubit.state,
    ).thenReturn(const ExchangeState(userSummary: _summary));
    when(() => cubit.connectWebSocket()).thenAnswer((_) => service.connect());
    when(
      () => cubit.reconnectWebSocket(),
    ).thenAnswer((_) => service.reconnect());
    when(
      () => cubit.disconnectWebSocket(),
    ).thenAnswer((_) => service.disconnect());
    when(() => cubit.fetchUserSummary()).thenAnswer((_) async {});
    final paused = Completer<void>();
    final resumed = Completer<void>();
    final observer = AppLifecycleListener(
      onStateChange: (state) {
        if (state == AppLifecycleState.paused && !paused.isCompleted) {
          paused.complete();
        }
        if (state == AppLifecycleState.resumed &&
            paused.isCompleted &&
            !resumed.isCompleted) {
          resumed.complete();
        }
      },
    );
    addTearDown(() async {
      foreground.dispose();
      observer.dispose();
      service.dispose();
      await cubit.close();
      for (final socket in sockets) {
        await socket.close();
      }
      await server.close(force: true);
    });
    await tester.pumpWidget(
      BlocProvider<ExchangeCubit>.value(
        value: cubit,
        child: const ExchangeListener(child: SizedBox()),
      ),
    );
    await service.connect();
    expect(datasource.isConnected, isTrue);
    expect(accepted, 1);

    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    expect(datasource.isConnected, isTrue);
    final inactiveMessage = datasource.messageStream.first;
    sockets.single.add('{"type":"balance"}');
    expect(await inactiveMessage, {'type': 'balance'});
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(accepted, 1);
    verifyNever(() => cubit.fetchUserSummary());

    const externalLifecycle = bool.fromEnvironment('WS_EXTERNAL_LIFECYCLE');
    if (externalLifecycle) {
      // The host presses Home and relaunches this test activity over ADB.
      // ignore: avoid_print
      print('WS_ANDROID_READY_BACKGROUND');
      await paused.future.timeout(const Duration(seconds: 45));
    } else {
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        binding.handleAppLifecycleStateChanged(state);
      }
    }
    expect(datasource.isConnected, isFalse);
    await _waitFor(() => closed == 1);
    // A caller cannot bypass the foreground gate, even through the delayed service path.
    await service.reconnect();
    expect(accepted, 1);
    if (externalLifecycle) {
      // ignore: avoid_print
      print('WS_ANDROID_BACKGROUND_GATED');
      await resumed.future.timeout(const Duration(seconds: 45));
    } else {
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
      ]) {
        binding.handleAppLifecycleStateChanged(state);
      }
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(accepted, 1);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }
    await _waitFor(() => datasource.isConnected);
    expect(accepted, 2);
    final message = datasource.messageStream.first;
    sockets.last.add('{"type":"balance"}');
    expect(await message, {'type': 'balance'});
    // ignore: avoid_print
    print('WS_ANDROID_LIFECYCLE_OK accepted=$accepted closed=$closed');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('disconnect aborts an unfinished native handshake', (
    tester,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestSeen = Completer<void>();
    server.listen((request) {
      if (!requestSeen.isCompleted) requestSeen.complete();
      // Deliberately hold the upgrade without returning a response.
    });
    final datasource = ExchangeNotificationDatasource(
      baseUrl: 'http://127.0.0.1:${server.port}',
      apiKeyDatasource: keys,
      isTestnet: false,
    );
    addTearDown(() async {
      datasource.dispose();
      await server.close(force: true);
    });
    final connecting = datasource.connect();
    await requestSeen.future.timeout(const Duration(seconds: 5));
    datasource.disconnect();
    await connecting.timeout(const Duration(seconds: 5));
    expect(datasource.isConnected, isFalse);
    // ignore: avoid_print
    print('WS_ANDROID_HANDSHAKE_CANCEL_OK');
  });
}
