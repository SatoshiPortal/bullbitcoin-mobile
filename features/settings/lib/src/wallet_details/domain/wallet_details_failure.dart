import 'package:primitives/primitives.dart';

/// Reading, deleting or rescanning one wallet from its settings failed.
sealed class WalletDetailsFailure extends Failure {
  const WalletDetailsFailure([super.logMessage]);
}

final class WalletDetailsNotFoundFailure extends WalletDetailsFailure {
  const WalletDetailsNotFoundFailure();
}

/// A default wallet is never deleted.
final class WalletDetailsDefaultFailure extends WalletDetailsFailure {
  const WalletDetailsDefaultFailure();
}

/// A swap or an Exchange order still uses the wallet.
final class WalletDetailsOngoingSwapsFailure extends WalletDetailsFailure {
  const WalletDetailsOngoingSwapsFailure();
}

/// A store could not prove the operation safe, or refused it.
final class WalletDetailsUnavailableFailure extends WalletDetailsFailure {
  const WalletDetailsUnavailableFailure([super.logMessage]);
}

/// An explicit wallet discovery could not complete.
final class WalletDetailsDiscoveryFailure extends WalletDetailsFailure {
  const WalletDetailsDiscoveryFailure();
}
