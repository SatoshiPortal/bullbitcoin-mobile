import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

/// Reuses the existing privacy policy, fallback loop and scoped Tor lifetime.
final class WalletConnectionPolicyImpl implements WalletConnectionPolicy {
  final ElectrumServersPort _servers;

  WalletConnectionPolicyImpl(this._servers);

  @override
  Future<Result<T, TransactionSyncFailure>> run<T>({
    required Network network,
    required Future<Result<T, TransactionSyncFailure>> Function(
      WalletConnection,
    )
    operation,
    required bool Function(TransactionSyncFailure) mayRetry,
  }) async {
    final legacyNetwork = switch (network) {
      BitcoinNetwork.mainnet => ElectrumServerNetwork.bitcoinMainnet,
      BitcoinNetwork.testnet => ElectrumServerNetwork.bitcoinTestnet,
      LiquidNetwork.mainnet => ElectrumServerNetwork.liquidMainnet,
      LiquidNetwork.testnet => ElectrumServerNetwork.liquidTestnet,
      BitcoinNetwork.signet ||
      BitcoinNetwork.regtest ||
      LiquidNetwork.regtest => null,
    };
    if (legacyNetwork == null) {
      return const Err(TransactionSyncUnsupportedNetworkFailure());
    }
    TransactionSyncFailure? lastFailure;
    try {
      return await _servers.runWithFallback(
        network: legacyNetwork,
        isTransient: (error) => error is _RetryableFailure,
        operation: (connection) async {
          final result = await operation(
            WalletConnection(
              url: connection.url,
              timeout: Duration(seconds: connection.effectiveTimeout),
              retry: connection.retry,
              stopGap: connection.stopGap,
              validateDomain: connection.validateDomain,
              socks5: connection.socks5,
            ),
          );
          if (result case Err(:final failure) when mayRetry(failure)) {
            lastFailure = failure;
            throw _RetryableFailure();
          }
          return result;
        },
      );
    } on Exception {
      // No URL, proxy, descriptor or foreign diagnostic escapes this boundary.
      // Exhaustion may wrap callback errors; preserve the last typed failure.
      return Err(lastFailure ?? const TransactionSyncConnectionFailure());
    }
  }
}

final class _RetryableFailure implements Exception {}
