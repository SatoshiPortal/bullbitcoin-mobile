import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/features/electrum_settings/data/wallet_connection_policy_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

final class _Servers extends ElectrumServersPort {
  ElectrumServerNetwork? selected;
  bool open = false;
  int attempts = 0;
  @override
  Future<T> runWithFallback<T>({
    required ElectrumServerNetwork network,
    required Future<T> Function(ElectrumConnection) operation,
    bool Function(Object)? isTransient,
  }) async {
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
          if (i == 1 || !(isTransient?.call(error) ?? false)) rethrow;
        }
      }
      throw StateError('Unreachable');
    } finally {
      open = false;
    }
  }
}

void main() {
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
        expect(connection.socks5, '127.0.0.1:9050');
        expect(connection.stopGap, 42);
        expect(connection.retry, 2);
        expect(connection.validateDomain, isTrue);
        return const Ok(7);
      },
    );
    expect(result, isA<Ok<int, TransactionSyncFailure>>());
    expect(servers.selected, ElectrumServerNetwork.liquidTestnet);
    expect(servers.open, isFalse);
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
      isA<Err<int, TransactionSyncFailure>>().having(
        (e) => e.failure,
        'failure',
        isA<TransactionSyncUnsupportedNetworkFailure>(),
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
          operation: (_) async => const Err(TransactionSyncBusyFailure()),
        );
        expect(servers.attempts, retry ? 2 : 1);
        expect(result, isA<Err<int, TransactionSyncFailure>>());
        expect(
          (result as Err<int, TransactionSyncFailure>).failure,
          isA<TransactionSyncBusyFailure>(),
        );
      }
    },
  );

  test(
    'exhausted fallback preserves the last distinct caller failure',
    () async {
      final servers = _Servers();
      const lastFailure = TransactionSyncStorageFailure();
      final result = await WalletConnectionPolicyImpl(servers).run<int>(
        network: BitcoinNetwork.mainnet,
        mayRetry: (_) => true,
        operation: (_) async => Err(
          servers.attempts == 1
              ? const TransactionSyncConnectionFailure()
              : lastFailure,
        ),
      );
      expect(servers.attempts, 2);
      expect(
        (result as Err<int, TransactionSyncFailure>).failure,
        same(lastFailure),
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
