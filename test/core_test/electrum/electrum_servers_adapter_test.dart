import 'package:bb_mobile/core/electrum/adapters/electrum_servers_adapter.dart';
import 'package:bb_mobile/core/electrum/domain/entities/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/entities/electrum_settings.dart';
import 'package:bb_mobile/core/electrum/domain/errors/electrum_fallback_exception.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_settings_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockServerRepository extends Mock implements ElectrumServerRepository {}

class _MockSettingsRepository extends Mock
    implements ElectrumSettingsRepository {}

class _MockAppSettingsRepository extends Mock implements SettingsRepository {}

const _network = ElectrumServerNetwork.bitcoinMainnet;
const _liquidNetwork = ElectrumServerNetwork.liquidMainnet;

ElectrumServer _server(String url, {bool isCustom = false, int priority = 0}) {
  return ElectrumServer.existing(
    url: url,
    network: _network,
    isCustom: isCustom,
    priority: priority,
  );
}

ElectrumSettings _settings({String? socks5}) {
  return ElectrumSettings(
    stopGap: 20,
    timeout: 10,
    retry: 3,
    validateDomain: true,
    network: _network,
    socks5: socks5,
  );
}

SettingsEntity _appSettings({
  bool useTorProxy = false,
  int torProxyPort = 9050,
}) {
  return SettingsEntity(
    environment: Environment.mainnet,
    bitcoinUnit: BitcoinUnit.sats,
    currencyCode: 'USD',
    useTorProxy: useTorProxy,
    torProxyPort: torProxyPort,
  );
}

void main() {
  late _MockServerRepository serverRepo;
  late _MockSettingsRepository settingsRepo;
  late _MockAppSettingsRepository appSettingsRepo;
  late ElectrumServersAdapter adapter;

  setUpAll(() {
    registerFallbackValue(_network);
  });

  setUp(() {
    serverRepo = _MockServerRepository();
    settingsRepo = _MockSettingsRepository();
    appSettingsRepo = _MockAppSettingsRepository();
    adapter = ElectrumServersAdapter(
      serverRepository: serverRepo,
      settingsRepository: settingsRepo,
      appSettingsRepository: appSettingsRepo,
    );
  });

  void stub({
    required List<ElectrumServer> servers,
    ElectrumSettings? settings,
    SettingsEntity? appSettings,
  }) {
    when(
      () => serverRepo.fetchActiveServers(network: any(named: 'network')),
    ).thenAnswer((_) async => Ok(servers));
    when(
      () => settingsRepo.fetchByNetwork(any()),
    ).thenAnswer((_) async => Ok(settings ?? _settings()));
    when(
      () => appSettingsRepo.fetch(),
    ).thenAnswer((_) async => appSettings ?? _appSettings());
  }

  group('runWithFallback — fallback semantics', () {
    test('returns the result from the first server on success', () async {
      stub(servers: [_server('ssl://a:50002'), _server('ssl://b:50002')]);
      final tried = <String>[];

      final result = await adapter.runWithFallback<String>(
        network: _network,
        operation: (connection) async {
          tried.add(connection.url);
          return 'ok';
        },
      );

      expect(result, 'ok');
      expect(tried, ['ssl://a:50002']); // second server never touched
    });

    test('falls back to the next server on a transient failure', () async {
      stub(servers: [_server('ssl://a:50002'), _server('ssl://b:50002')]);
      final tried = <String>[];

      final result = await adapter.runWithFallback<String>(
        network: _network,
        operation: (connection) async {
          tried.add(connection.url);
          if (connection.url == 'ssl://a:50002') throw Exception('timeout');
          return 'ok-from-b';
        },
      );

      expect(result, 'ok-from-b');
      expect(tried, ['ssl://a:50002', 'ssl://b:50002']);
    });

    test('throws AllElectrumServersFailedException listing every attempt', () async {
      stub(servers: [_server('ssl://a:50002'), _server('ssl://b:50002')]);

      await expectLater(
        adapter.runWithFallback<String>(
          network: _network,
          operation: (_) async => throw Exception('down'),
        ),
        throwsA(
          isA<AllElectrumServersFailedException>().having(
            (e) => e.attempts.map((a) => a.url).toList(),
            'attempts',
            ['ssl://a:50002', 'ssl://b:50002'],
          ),
        ),
      );
    });

    test('rethrows immediately on a permanent error (no fallback)', () async {
      stub(servers: [_server('ssl://a:50002'), _server('ssl://b:50002')]);
      final tried = <String>[];

      await expectLater(
        adapter.runWithFallback<String>(
          network: _network,
          isTransient: (_) => false, // every error is permanent
          operation: (connection) async {
            tried.add(connection.url);
            throw const FormatException('bad tx');
          },
        ),
        throwsA(isA<FormatException>()),
      );

      expect(tried, ['ssl://a:50002']); // short-circuited, never tried b
    });

    test('throws NoElectrumServersConfiguredException when set is empty', () async {
      stub(servers: []);

      await expectLater(
        adapter.runWithFallback<String>(
          network: _network,
          operation: (_) async => 'unreachable',
        ),
        throwsA(isA<NoElectrumServersConfiguredException>()),
      );
    });

    test('R2a: custom-only set + all fail → never reaches defaults', () async {
      // fetchActiveServers returns ONLY custom servers when a custom is set
      // (its own contract); the executor must iterate just those and fail,
      // never reaching for the default set on its own.
      stub(
        servers: [_server('ssl://my-node:50002', isCustom: true, priority: 0)],
      );

      await expectLater(
        adapter.runWithFallback<String>(
          network: _network,
          operation: (_) async => throw Exception('my node down'),
        ),
        throwsA(
          isA<AllElectrumServersFailedException>()
              .having((e) => e.triedCustomServers, 'triedCustomServers', true)
              .having(
                (e) => e.attempts.every((a) => a.isCustom),
                'all attempts custom',
                true,
              ),
        ),
      );

      // The executor must not have reached for defaults or any other source
      // beyond the single active-set resolution.
      verify(
        () => serverRepo.fetchActiveServers(network: any(named: 'network')),
      ).called(1);
      verifyNoMoreInteractions(serverRepo);
    });
  });

  group('runWithFallback — connection assembly', () {
    test('merges electrum settings into every connection', () async {
      stub(
        servers: [_server('ssl://a:50002')],
        settings: _settings(),
      );

      late final dynamic seen;
      await adapter.runWithFallback<void>(
        network: _network,
        operation: (connection) async {
          seen = connection;
        },
      );

      expect(seen.url, 'ssl://a:50002');
      expect(seen.retry, 3);
      expect(seen.timeout, 10);
      expect(seen.stopGap, 20);
      expect(seen.validateDomain, true);
      expect(seen.isCustom, false);
    });

    test('Tor disabled → uses the persisted socks5 (which may be null)', () async {
      stub(
        servers: [_server('ssl://a:50002')],
        settings: _settings(),
        appSettings: _appSettings(useTorProxy: false),
      );

      late final String? socks5;
      await adapter.runWithFallback<void>(
        network: _network,
        operation: (connection) async {
          socks5 = connection.socks5;
        },
      );

      expect(socks5, isNull);
    });

    test('Tor enabled on Bitcoin → injects 127.0.0.1:<port>', () async {
      stub(
        servers: [_server('ssl://a:50002')],
        settings: _settings(),
        appSettings: _appSettings(useTorProxy: true, torProxyPort: 9150),
      );

      late final String? socks5;
      await adapter.runWithFallback<void>(
        network: _network,
        operation: (connection) async {
          socks5 = connection.socks5;
        },
      );

      expect(socks5, '127.0.0.1:9150');
    });

    test(
      'Tor enabled but persisted socks5 set → persisted wins',
      () async {
        stub(
          servers: [_server('ssl://a:50002')],
          settings: _settings(socks5: 'proxy.example:9999'),
          appSettings: _appSettings(useTorProxy: true, torProxyPort: 9150),
        );

        late final String? socks5;
        await adapter.runWithFallback<void>(
          network: _network,
          operation: (connection) async {
            socks5 = connection.socks5;
          },
        );

        expect(socks5, 'proxy.example:9999');
      },
    );

    test('Tor enabled on Liquid → socks5 is NOT applied', () async {
      when(
        () => serverRepo.fetchActiveServers(network: any(named: 'network')),
      ).thenAnswer(
        (_) async => Ok([
          ElectrumServer.existing(
            url: 'ssl://liquid.example:50002',
            network: _liquidNetwork,
            isCustom: false,
            priority: 0,
          ),
        ]),
      );
      when(
        () => settingsRepo.fetchByNetwork(any()),
      ).thenAnswer((_) async => Ok(_settings()));
      when(
        () => appSettingsRepo.fetch(),
      ).thenAnswer(
        (_) async => _appSettings(useTorProxy: true, torProxyPort: 9150),
      );

      late final String? socks5;
      await adapter.runWithFallback<void>(
        network: _liquidNetwork,
        operation: (connection) async {
          socks5 = connection.socks5;
        },
      );

      expect(socks5, isNull);
    });
  });
}
