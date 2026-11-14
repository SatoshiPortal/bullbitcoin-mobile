import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

final class FixtureConnections implements WalletConnectionPort {
  final List<String> urls;
  final String? socks5;
  int attempts = 0;
  bool routeActive = false;

  FixtureConnections(this.urls, {this.socks5});

  @override
  Future<Result<T, TransactionSyncFailure>> run<T>({
    required Network network,
    required Future<Result<T, TransactionSyncFailure>> Function(
      WalletConnection,
    )
    operation,
    required bool Function(TransactionSyncFailure) mayRetry,
  }) async {
    routeActive = true;
    try {
      for (final url in urls) {
        attempts++;
        final result = await operation(
          WalletConnection(
            url: url,
            socks5: socks5,
            timeout: const Duration(seconds: 1),
            retry: 0,
            stopGap: 20,
            validateDomain: false,
          ),
        );
        if (result case Err(:final failure) when mayRetry(failure)) continue;
        return result;
      }
      return const Err(TransactionSyncConnectionFailure());
    } finally {
      routeActive = false;
    }
  }
}
