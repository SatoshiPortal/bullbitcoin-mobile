import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'transaction_sync_failure.dart';

/// Valid only inside the policy callback, while its Tor route remains alive.
final class WalletConnection {
  final String url;
  final Duration timeout;
  final int retry;
  final int stopGap;
  final bool validateDomain;
  final String? socks5;

  const WalletConnection({
    required this.url,
    required this.timeout,
    required this.retry,
    required this.stopGap,
    required this.validateDomain,
    this.socks5,
  });
}

/// The owner selects custom-or-default servers and manages scoped Tor routes.
/// The caller may request fallback ONLY before any native mutation. It must
/// await all work using the connection before returning from the callback.
/// The operation must report recoverable failures through [Result], never throw.
/// A thrown [Exception] ends the run without caller-requested fallback and becomes [TransactionSyncConnectionFailure]; [Error]s propagate to the caller.
/// Exhausted fallback preserves the last failure returned by the caller.
abstract interface class WalletConnectionPolicy {
  @useResult
  Future<Result<T, TransactionSyncFailure>> run<T>({
    required Network network,
    required Future<Result<T, TransactionSyncFailure>> Function(
      WalletConnection,
    )
    operation,
    required bool Function(TransactionSyncFailure) mayRetry,
  });
}
