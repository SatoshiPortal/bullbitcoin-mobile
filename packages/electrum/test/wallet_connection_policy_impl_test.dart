import 'package:electrum/src/data/wallet_connection_policy_impl.dart';
import 'package:electrum/src/domain/electrum_network_unauthorized_exception.dart';
import 'package:electrum/electrum.dart';
import 'package:electrum/setup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

final class _Servers extends ElectrumServersPort {
  @override
  Future<bool> hasCustomServers({
    required ElectrumServerNetwork network,
  }) async => false;

  ElectrumServerNetwork? selected;
  bool open = false;
  int attempts = 0;
  bool authorized = true;
  @override
  Future<T> runWithFallback<T>({
    required ElectrumServerNetwork network,
    required Future<T> Function(ElectrumConnection) operation,
    bool Function(Object)? isTransient,
  }) async {
    if (!authorized) throw const ElectrumNetworkUnauthorizedException();
    selected = network;
    open = true;
    try {
      for (var i = 0; i < 2; i++) {
        attempts++;
        try {
          return await operation(
            const ElectrumConnection(
              url: 'ssl://example.onion:50002',
              retry: 2,
              timeout: 1,
              stopGap: 42,
              validateDomain: true,
              isCustom: true,
              socks5: '127.0.0.1:9050',
            ),
          );
        } catch (error) {
          if (!(isTransient?.call(error) ?? false)) rethrow;
          if (i == 1) throw AllElectrumServersFailedException([]);
        }
      }
      throw StateError('Unreachable');
    } finally {
      open = false;
    }
  }
}

void main() {
  test(
    'authorization refusal is preserved for foreground and headless sync',
    () async {
      final servers = _Servers()..authorized = false;
      var operations = 0;
      final result = await WalletConnectionPolicyImpl(servers).run<int>(
        network: BitcoinNetwork.regtest,
        mayRetry: (_) => true,
        operation: (_) async {
          operations++;
          return const Ok(1);
        },
      );
      expect(
        result,
        isA<Err<int, SyncFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<SyncUnauthorizedNetworkFailure>(),
        ),
      );
      expect(operations, 0);
      expect(servers.attempts, 0);
    },
  );

  test('maps network and effective settings within the scoped route', () async {
    final servers = _Servers();
    final policy = WalletConnectionPolicyImpl(servers);
    final result = await policy.run<int>(
      network: LiquidNetwork.testnet,
      mayRetry: (_) => false,
      operation: (connection) async {
        await Future<void>.delayed(Duration.zero);
        expect(servers.open, isTrue);
        expect(
          connection.timeout.inSeconds,
          ElectrumConnection.onionMinimumTimeout,
        );
        expect(connection.socks5, isNull);
        expect(connection.stopGap, 42);
        expect(connection.retry, 2);
        expect(connection.validateDomain, isTrue);
        return const Ok(7);
      },
    );
    expect(result, isA<Ok<int, SyncFailure>>());
    expect(servers.selected, ElectrumServerNetwork.liquidTestnet);
    expect(servers.open, isFalse);
  });

  test('regtest selects only the concrete Bitcoin regtest policy', () async {
    final servers = _Servers();
    final result = await WalletConnectionPolicyImpl(servers).run<int>(
      network: BitcoinNetwork.regtest,
      mayRetry: (_) => false,
      operation: (connection) async {
        expect(connection.socks5, '127.0.0.1:9050');
        return const Ok(1);
      },
    );
    expect(result, isA<Ok<int, SyncFailure>>());
    expect(servers.selected, ElectrumServerNetwork.bitcoinRegtest);
  });

  test('Liquid regtest resolves its own servers', () async {
    // Supported since lwk-dart#99 expresses Liquid regtest.
    final servers = _Servers();
    final result = await WalletConnectionPolicyImpl(servers).run<int>(
      network: LiquidNetwork.regtest,
      mayRetry: (_) => false,
      operation: (_) async => const Ok(1),
    );
    expect(result, isA<Ok<int, SyncFailure>>());
  });

  test('unsupported networks never enter the legacy policy', () async {
    final servers = _Servers();
    final result = await WalletConnectionPolicyImpl(servers).run<int>(
      network: BitcoinNetwork.signet,
      mayRetry: (_) => false,
      operation: (_) async => const Ok(1),
    );
    expect(
      result,
      isA<Err<int, SyncFailure>>().having(
        (e) => e.failure,
        'failure',
        isA<SyncUnsupportedNetworkFailure>(),
      ),
    );
    expect(servers.attempts, 0);
  });

  test(
    'busy is preserved and fallback requires explicit pre-mutation consent',
    () async {
      for (final retry in [false, true]) {
        final servers = _Servers();
        final result = await WalletConnectionPolicyImpl(servers).run<int>(
          network: BitcoinNetwork.mainnet,
          mayRetry: (_) => retry,
          operation: (_) async => const Err(SyncBusyFailure()),
        );
        expect(servers.attempts, retry ? 2 : 1);
        expect(result, isA<Err<int, SyncFailure>>());
        expect(
          (result as Err<int, SyncFailure>).failure,
          isA<SyncBusyFailure>(),
        );
      }
    },
  );

  test(
    'exhausted fallback preserves the last distinct caller failure',
    () async {
      final servers = _Servers();
      const lastFailure = SyncStorageFailure();
      final result = await WalletConnectionPolicyImpl(servers).run<int>(
        network: BitcoinNetwork.mainnet,
        mayRetry: (_) => true,
        operation: (_) async => Err(
          servers.attempts == 1 ? const SyncConnectionFailure() : lastFailure,
        ),
      );
      expect(servers.attempts, 2);
      expect((result as Err<int, SyncFailure>).failure, same(lastFailure));
      expect(servers.open, isFalse);
    },
  );

  test(
    'a thrown exception does not preserve a previous retryable failure',
    () async {
      final servers = _Servers();
      final result = await WalletConnectionPolicyImpl(servers).run<int>(
        network: BitcoinNetwork.mainnet,
        mayRetry: (_) => true,
        operation: (_) async {
          if (servers.attempts == 1) {
            return const Err(SyncBusyFailure());
          }
          throw Exception('connection failed');
        },
      );
      expect(servers.attempts, 2);
      expect(
        (result as Err<int, SyncFailure>).failure,
        isA<SyncConnectionFailure>(),
      );
      expect(servers.open, isFalse);
    },
  );

  test('programmer errors propagate and the route is released', () async {
    final servers = _Servers();
    await expectLater(
      WalletConnectionPolicyImpl(servers).run<int>(
        network: BitcoinNetwork.mainnet,
        mayRetry: (_) => true,
        operation: (_) async => throw StateError('bug'),
      ),
      throwsStateError,
    );
    expect(servers.attempts, 1);
    expect(servers.open, isFalse);
  });
}
