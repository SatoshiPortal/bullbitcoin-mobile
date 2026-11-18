import 'dart:async';

import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/settings/data/recoverbull_settings_adapter.dart';
import 'package:bb_mobile/features/settings/domain/regtest_recoverbull_profile.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/settings/public/recoverbull_bindings.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_tor/tor.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart'
    show BitcoinUnit, NetworkEnv, RegtestHostProfile;

class _Settings extends Mock implements SettingsRepository {}

class _Embedded extends Mock implements EmbeddedTor {}

class _External extends Mock implements ExternalTor {}

class _Sessions extends Mock implements TorSessions {}

class _Tor extends Mock implements Tor {}

class _UnreadDatabase extends Mock implements SqliteDatabase {}

SettingsEntity _selected(
  Environment environment, {
  bool enabled = true,
  bool useProxy = true,
}) => SettingsEntity(
  environment: environment,
  bitcoinUnit: BitcoinUnit.btc,
  currencyCode: 'USD',
  isSuperuser: true,
  isDevModeEnabled: enabled,
  useTorProxy: useProxy,
  torProxyPort: 9151,
);

RegtestRecoverBullProfile _profile() => RegtestRecoverBullProfile(
  RegtestHostProfile.forNetwork(NetworkEnv.regtest, host: 'stack.example') ??
      (throw StateError('Missing test profile')),
);

TorReady _ready(TorProxyEndpoint endpoint) => TorReady(
  TorRoute(
    source: TorSource.external,
    endpoint: endpoint,
    evidence: TorReadinessEvidence.externalSocksHandshake,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(
    () =>
        registerFallbackValue(TorProxyEndpoint(host: '127.0.0.1', port: 9151)),
  );
  late _Settings settings;
  late _Embedded embedded;
  late _External external;
  late _Tor tor;
  late SqliteDatabase database;
  late SettingsEntity selected;
  final adapters = <RecoverBullSettingsAdapter>[];
  setUp(() {
    settings = _Settings();
    embedded = _Embedded();
    external = _External();
    tor = _Tor();
    database = SqliteDatabase(NativeDatabase.memory());
    selected = _selected(Environment.regtest);
    when(settings.fetch).thenAnswer((_) async => selected);
    when(() => tor.external).thenReturn(external);
    when(() => tor.embedded).thenReturn(embedded);
    when(() => embedded.ensureReady())
        .thenAnswer((_) async => const TorStopped(TorSource.embedded));
    when(() => external.verify(any())).thenAnswer(
      (call) async =>
          _ready(call.positionalArguments.single as TorProxyEndpoint),
    );
  });
  tearDown(() async {
    for (final adapter in adapters) {
      await adapter.close();
    }
    adapters.clear();
    await database.close();
  });
  RecoverBullSettingsAdapter adapter({bool regtest = true}) {
    final value = RecoverBullSettingsAdapter(
      settings,
      database,
      embedded,
      tor,
      regtestProfile: regtest ? _profile() : null,
    );
    adapters.add(value);
    return value;
  }

  for (final production in [Environment.mainnet, Environment.testnet]) {
    for (final startsOnRegtest in [false, true]) {
      final initial = startsOnRegtest ? Environment.regtest : production;
      final target = startsOnRegtest ? production : Environment.regtest;
      test(
        '$initial to $target refuses the captured runtime before route or database access',
        () async {
          selected = _selected(initial);
          final services = GetIt.asNewInstance();
          final unreadDatabase = _UnreadDatabase();
          services.registerSingleton<SettingsRepository>(settings);
          services.registerSingleton<SqliteDatabase>(unreadDatabase);
          services.registerSingleton<Tor>(tor);
          addTearDown(services.reset);
          final capturedPath = await SettingsRecoverBullBindings.setup(
            services,
            databasePath: '/tmp/scope/recoverbull.sqlite',
            regtestHost: 'stack.example',
          );
          expect(
            capturedPath,
            startsOnRegtest
                ? '/tmp/scope/recoverbull-regtest.sqlite'
                : '/tmp/scope/recoverbull.sqlite',
          );
          expect(
            await services<RecoverBullEnvironmentPort>().currentNetwork(),
            isA<Ok<BitcoinNetwork, RecoverBullFailure>>().having(
              (result) => result.value.name,
              'captured network',
              initial.name,
            ),
          );
          selected = _selected(target);
          expect(
            await services<RecoverBullEnvironmentPort>().currentNetwork(),
            isA<Err<BitcoinNetwork, RecoverBullFailure>>().having(
              (result) => result.failure,
              'failure',
              isA<VaultContextChangedFailure>(),
            ),
          );
          expect(
            await services<RecoverBullLegacySettingsPort>().read(),
            isA<Err<LegacyBackupSettings, RecoverBullFailure>>().having(
              (result) => result.failure,
              'failure',
              isA<VaultContextChangedFailure>(),
            ),
          );
          expect(
            await services<RecoverBullRoutePort>().open(),
            isA<Err<RecoverBullRoute, RecoverBullFailure>>().having(
              (result) => result.failure,
              'failure',
              isA<VaultContextChangedFailure>(),
            ),
          );
          verifyZeroInteractions(unreadDatabase);
          verifyZeroInteractions(external);
          verifyZeroInteractions(embedded);
        },
      );
    }
  }

  for (final production in [Environment.mainnet, Environment.testnet]) {
    for (final stage in [
      'external',
      'bootstrap',
      'session',
      'session settings failure',
    ]) {
      test(
        'late production $production refuses regtest after $stage await',
        () async {
          selected = _selected(production, useProxy: stage == 'external');
          final pendingReady = Completer<TorConnectionState>();
          final pendingSession = Completer<TorSession>();
          final sessions = _Sessions();
          var sessionCloses = 0;
          final endpoint = TorProxyEndpoint(host: '127.0.0.1', port: 12345);
          final session = TorSession(endpoint, TorTransport.direct, () async {
            sessionCloses += 1;
          });
          final embeddedReady = TorReady(
            TorRoute(
              source: TorSource.embedded,
              endpoint: endpoint,
              evidence: TorReadinessEvidence.embeddedBootstrap,
              transport: TorTransport.direct,
            ),
          );
          when(() => embedded.sessions).thenReturn(sessions);
          when(sessions.open).thenAnswer((_) async => session);
          if (stage == 'external') {
            when(() => external.verify(any()))
                .thenAnswer((_) => pendingReady.future);
          } else if (stage == 'bootstrap') {
            when(embedded.ensureReady).thenAnswer((_) => pendingReady.future);
          } else {
            when(embedded.ensureReady).thenAnswer((_) async => embeddedReady);
            when(sessions.open).thenAnswer((_) => pendingSession.future);
          }
          final result = adapter(regtest: false).open();
          await pumpEventQueue();
          selected = _selected(Environment.regtest);
          if (stage.startsWith('session')) {
            if (stage == 'session settings failure') {
              when(settings.fetch).thenThrow(Exception('Settings unavailable'));
            }
            pendingSession.complete(session);
          } else {
            pendingReady.complete(
              stage == 'external' ? _ready(endpoint) : embeddedReady,
            );
          }
          expect(
            await result,
            isA<Err<RecoverBullRoute, RecoverBullFailure>>().having(
              (result) => result.failure,
              'failure',
              isA<VaultContextChangedFailure>(),
            ),
          );
          if (stage.startsWith('session')) {
            verify(sessions.open).called(1);
            expect(sessionCloses, 1);
          } else {
            verifyNever(sessions.open);
            expect(sessionCloses, 0);
          }
        },
      );
    }
  }

  test('regtest preserves the selected concrete network', () async {
    expect(
      await adapter().currentNetwork(),
      isA<Ok<BitcoinNetwork, RecoverBullFailure>>().having(
        (r) => r.value,
        'network',
        BitcoinNetwork.regtest,
      ),
    );
  });
  test('regtest uses only the captured fixture SOCKS route', () async {
    final value = adapter();
    final result = await value.open();
    expect(result, isA<Ok<RecoverBullRoute, RecoverBullFailure>>());
    final endpoint =
        verify(() => external.verify(captureAny())).captured.single
            as TorProxyEndpoint;
    expect(endpoint.host, 'stack.example');
    expect(endpoint.port, 59051);
    expect(value.snowflakeAvailable, isFalse);
    verifyZeroInteractions(embedded);
  });
  test(
    'regtest legacy import is the fixture without production consent',
    () async {
      final result = await adapter().read();
      expect(
        result,
        isA<Ok<LegacyBackupSettings, RecoverBullFailure>>()
            .having(
              (r) => r.value.server.toString(),
              'server',
              'http://regtest.recoverbull.onion:3000',
            )
            .having((r) => r.value.permissionGranted, 'consent', false),
      );
    },
  );
  test('route observation publishes the verified external state', () async {
    final value = adapter();
    final states = <TorConnectionState>[];
    final subscription = value.watch().listen(states.add);
    await pumpEventQueue();
    await value.open();
    await pumpEventQueue();
    expect(states.whereType<TorReady>(), hasLength(1));
    await subscription.cancel();
    verifyZeroInteractions(embedded);
  });
  test(
    'an authorization change during verification refuses the route',
    () async {
      final pending = Completer<TorConnectionState>();
      when(() => external.verify(any())).thenAnswer((_) => pending.future);
      final result = adapter().open();
      await pumpEventQueue();
      selected = _selected(Environment.mainnet);
      pending.complete(_ready(_profile().endpoint));
      expect(
        await result,
        isA<Err<RecoverBullRoute, RecoverBullFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<VaultContextChangedFailure>(),
        ),
      );
      verifyZeroInteractions(embedded);
    },
  );
  test(
    'disabled developer access refuses before any route verification',
    () async {
      selected = _selected(Environment.regtest, enabled: false);
      expect(
        await adapter().open(),
        isA<Err<RecoverBullRoute, RecoverBullFailure>>(),
      );
      verifyZeroInteractions(external);
      verifyZeroInteractions(embedded);
    },
  );
  test('production runtime refuses a later regtest selection', () async {
    expect(
      await adapter(regtest: false).open(),
      isA<Err<RecoverBullRoute, RecoverBullFailure>>(),
    );
    verifyZeroInteractions(external);
    verifyZeroInteractions(embedded);
  });
  for (final environment in [Environment.mainnet, Environment.testnet]) {
    test(
      '$environment preserves the original external route and legacy row',
      () async {
        selected = _selected(environment);
        final value = adapter(regtest: false);
        final row = await database.managers.recoverbull
            .filter((f) => f.id(1))
            .getSingle();
        expect(
          await value.currentNetwork(),
          isA<Ok<BitcoinNetwork, RecoverBullFailure>>().having(
            (r) => r.value.name,
            'network',
            environment.name,
          ),
        );
        expect(
          await value.read(),
          isA<Ok<LegacyBackupSettings, RecoverBullFailure>>()
              .having((r) => r.value.server.toString(), 'server', row.url)
              .having(
                (r) => r.value.permissionGranted,
                'permission',
                row.isPermissionGranted,
              ),
        );
        expect(
          await value.open(),
          isA<Ok<RecoverBullRoute, RecoverBullFailure>>(),
        );
        final endpoint =
            verify(() => external.verify(captureAny())).captured.single
                as TorProxyEndpoint;
        expect(endpoint.host, '127.0.0.1');
        expect(endpoint.port, 9151);
        verifyZeroInteractions(embedded);
      },
    );
  }
  for (final environment in Environment.values) {
    test(
      '$environment composition selects its isolated storage path',
      () async {
        selected = _selected(environment);
        final services = GetIt.asNewInstance();
        services.registerSingleton<SettingsRepository>(settings);
        services.registerSingleton<SqliteDatabase>(database);
        services.registerSingleton<Tor>(tor);
        final path = await SettingsRecoverBullBindings.setup(
          services,
          databasePath: '/tmp/scope/recoverbull.sqlite',
          regtestHost: 'stack.example',
        );
        expect(
          path,
          environment == Environment.regtest
              ? '/tmp/scope/recoverbull-regtest.sqlite'
              : '/tmp/scope/recoverbull.sqlite',
        );
        await services.reset();
      },
    );
  }
}
