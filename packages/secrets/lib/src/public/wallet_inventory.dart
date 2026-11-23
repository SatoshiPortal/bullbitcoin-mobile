import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../domain/failures.dart';
import '../domain/wallet_registration.dart';

/// Foreground reads from the currently authorized wallet inventory.
abstract interface class WalletInventory {
  /// Resolve a visible wallet without handing the caller its descriptors.
  /// Absence, unreadable rows and storage errors are distinct failures.
  @useResult
  Future<Result<WalletRegistration, SecretFailure>> readWallet(String id);

  /// Read choices for exactly [network], with no fallback to another network.
  /// Skips unreadable rows unless there are rows but none can be read.
  /// Networks with no persisted representation are unsupported.
  @useResult
  Future<Result<WalletSelection, SecretFailure>> walletsForNetwork(
    Network network,
  );
}
