import 'package:primitives/primitives.dart' show Failure;

/// Failures of an explicit, wallet-scoped discovery request.
sealed class WalletDiscoveryFailure extends Failure {
  const WalletDiscoveryFailure();
}

final class WalletDiscoveryUnavailableFailure extends WalletDiscoveryFailure {
  const WalletDiscoveryUnavailableFailure();
}

final class WalletDiscoverySyncFailure extends WalletDiscoveryFailure {
  const WalletDiscoverySyncFailure();
}
