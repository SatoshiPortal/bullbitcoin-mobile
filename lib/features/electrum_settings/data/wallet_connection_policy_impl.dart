import 'package:bb_mobile/features/electrum_settings/domain/electrum_network_unauthorized_exception.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_server_network.dart';
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
    final serverNetwork = switch (network) {
      BitcoinNetwork.mainnet => ElectrumServerNetwork.bitcoinMainnet,
      BitcoinNetwork.testnet => ElectrumServerNetwork.bitcoinTestnet,
      BitcoinNetwork.regtest => ElectrumServerNetwork.bitcoinRegtest,
      LiquidNetwork.mainnet => ElectrumServerNetwork.liquidMainnet,
      LiquidNetwork.testnet => ElectrumServerNetwork.liquidTestnet,
      BitcoinNetwork.signet ||
      // TODO(SatoshiPortal/lwk-dart#96): enable only after the pinned SDK
      // exposes LiquidNetwork.regtest and its native lifecycle is verified.
      LiquidNetwork.regtest => null,
    };
    if (serverNetwork == null) {
      log.config('Wallet connection unavailable network=$network');
      return const Err(TransactionSyncUnsupportedNetworkFailure());
    }
    TransactionSyncFailure? lastFailure;
    try {
      return await _servers.runWithFallback(
        network: serverNetwork,
        isTransient: (error) => error is _RetryableFailure,
        operation: (connection) async {
          final result = await operation(
            WalletConnection(
              url: connection.url,
              timeout: Duration(seconds: connection.effectiveTimeout),
              retry: connection.retry,
              stopGap: connection.stopGap,
              validateDomain: connection.validateDomain,
              socks5: network is LiquidNetwork ? null : connection.socks5,
            ),
          );
          if (result case Err(:final failure) when mayRetry(failure)) {
            lastFailure = failure;
            throw _RetryableFailure();
          }
          return result;
        },
      );
    } on ElectrumNetworkUnauthorizedException {
      return const Err(TransactionSyncUnsupportedNetworkFailure());
    } on Exception {
      // No URL, proxy, descriptor or foreign diagnostic escapes this boundary.
      // Exhaustion may wrap callback errors; preserve the last typed failure.
      return Err(lastFailure ?? const TransactionSyncConnectionFailure());
    }
  }
}

final class _RetryableFailure implements Exception {}
