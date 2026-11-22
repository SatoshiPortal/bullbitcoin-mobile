import 'package:electrum/src/domain/electrum_network_unauthorized_exception.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:electrum/src/domain/errors/electrum_fallback_exception.dart';
import 'package:electrum/src/domain/ports/electrum_servers_port.dart';
import 'package:electrum/src/domain/electrum_server_network.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

/// Reuses the existing privacy policy, fallback loop and scoped Tor lifetime.
final class WalletConnectionPolicyImpl implements WalletConnectionPort {
  final RunElectrumWithFallback _runWithFallback;

  WalletConnectionPolicyImpl(this._runWithFallback);

  @override
  Future<Result<T, SyncFailure>> run<T>({
    required Network network,
    required Future<Result<T, SyncFailure>> Function(WalletConnection)
    operation,
    required bool Function(SyncFailure) mayRetry,
  }) async {
    final serverNetwork = switch (network) {
      BitcoinNetwork.mainnet => ElectrumServerNetwork.bitcoinMainnet,
      BitcoinNetwork.testnet => ElectrumServerNetwork.bitcoinTestnet,
      BitcoinNetwork.regtest => ElectrumServerNetwork.bitcoinRegtest,
      LiquidNetwork.mainnet => ElectrumServerNetwork.liquidMainnet,
      LiquidNetwork.testnet => ElectrumServerNetwork.liquidTestnet,
      LiquidNetwork.regtest => ElectrumServerNetwork.liquidRegtest,
      BitcoinNetwork.signet => null,
    };
    if (serverNetwork == null) {
      log.config('Wallet connection unavailable network=$network');
      return const Err(SyncUnsupportedNetworkFailure());
    }
    SyncFailure? lastFailure;
    try {
      final result = await _runWithFallback(
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
              // ⚠️ Liquid never goes through Tor: LWK has no SOCKS option.
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
      return switch (result) {
        Ok(:final value) => value,
        Err() => const Err(SyncConnectionFailure()),
      };
    } on ElectrumNetworkUnauthorizedException {
      return const Err(SyncUnauthorizedNetworkFailure());
    } on AllElectrumServersFailedException {
      // Exhaustion wraps retryable callback failures; preserve the last one.
      return Err(lastFailure ?? const SyncConnectionFailure());
    } on Exception {
      // No URL, proxy, descriptor or foreign diagnostic escapes this boundary.
      return const Err(SyncConnectionFailure());
    }
  }
}

final class _RetryableFailure implements Exception {}
