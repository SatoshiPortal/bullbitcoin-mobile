import 'package:bb_mobile/core/electrum/adapters/electrum_servers_adapter.dart';
import 'package:bb_mobile/core/electrum/domain/entities/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/errors/electrum_fallback_exception.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockElectrumServerRepository extends Mock
    implements ElectrumServerRepository {}

const _network = ElectrumServerNetwork.bitcoinMainnet;

ElectrumServer _server(String url, {bool isCustom = false, int priority = 0}) {
  return ElectrumServer.existing(
    url: url,
    network: _network,
    isCustom: isCustom,
    priority: priority,
  );
}

void main() {
  late _MockElectrumServerRepository repo;
  late ElectrumServersAdapter adapter;

  setUpAll(() {
    registerFallbackValue(_network);
  });

  setUp(() {
    repo = _MockElectrumServerRepository();
    adapter = ElectrumServersAdapter(repository: repo);
  });

  void stubActiveServers(List<ElectrumServer> servers) {
    when(
      () => repo.fetchActiveServers(network: any(named: 'network')),
    ).thenAnswer((_) async => servers);
  }

  group('runWithFallback', () {
    test('returns the result from the first server on success', () async {
      stubActiveServers([_server('ssl://a:50002'), _server('ssl://b:50002')]);
      final tried = <String>[];

      final result = await adapter.runWithFallback<String>(
        network: _network,
        operation: (server) async {
          tried.add(server.url);
          return 'ok';
        },
      );

      expect(result, 'ok');
      expect(tried, ['ssl://a:50002']); // second server never touched
    });

    test('falls back to the next server on a transient failure', () async {
      stubActiveServers([_server('ssl://a:50002'), _server('ssl://b:50002')]);
      final tried = <String>[];

      final result = await adapter.runWithFallback<String>(
        network: _network,
        operation: (server) async {
          tried.add(server.url);
          if (server.url == 'ssl://a:50002') throw Exception('timeout');
          return 'ok-from-b';
        },
      );

      expect(result, 'ok-from-b');
      expect(tried, ['ssl://a:50002', 'ssl://b:50002']);
    });

    test(
      'throws AllElectrumServersFailedException listing every attempt',
      () async {
        stubActiveServers([_server('ssl://a:50002'), _server('ssl://b:50002')]);

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
      },
    );

    test('rethrows immediately on a permanent error (no fallback)', () async {
      stubActiveServers([_server('ssl://a:50002'), _server('ssl://b:50002')]);
      final tried = <String>[];

      await expectLater(
        adapter.runWithFallback<String>(
          network: _network,
          isTransient: (_) => false, // every error is permanent
          operation: (server) async {
            tried.add(server.url);
            throw const FormatException('bad tx');
          },
        ),
        throwsA(isA<FormatException>()),
      );

      expect(tried, ['ssl://a:50002']); // short-circuited, never tried b
    });

    test(
      'throws NoElectrumServersConfiguredException when set is empty',
      () async {
        stubActiveServers([]);

        await expectLater(
          adapter.runWithFallback<String>(
            network: _network,
            operation: (_) async => 'unreachable',
          ),
          throwsA(isA<NoElectrumServersConfiguredException>()),
        );
      },
    );

    test(
      'R2a: custom set + all custom fail → never reaches defaults',
      () async {
        // fetchActiveServers returns ONLY custom servers when a custom is set
        // (its own contract); the executor must iterate just those and fail,
        // never reaching for the default set on its own.
        stubActiveServers([
          _server('ssl://my-node:50002', isCustom: true, priority: 0),
        ]);

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

        // The executor must not have reached for defaults or any other source.
        verify(
          () => repo.fetchActiveServers(network: any(named: 'network')),
        ).called(1);
        verifyNoMoreInteractions(repo);
      },
    );
  });
}
