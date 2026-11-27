import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../domain/failures.dart';
import '../domain/wallet_registration.dart';

/// Foreground reads from the currently authorized wallet inventory.
abstract interface class WalletInventory {
  /// Public origins across the authorized view, including watch-only wallets.
  @useResult
  Future<Result<List<Fingerprint>, SecretFailure>> referencedFingerprints();

  /// Resolve a visible wallet without handing the caller its descriptors.
  /// Absence, unreadable rows and storage errors are distinct failures.
  @useResult
  Future<Result<WalletRegistration, SecretFailure>> readWallet(String id);

  /// Whether Ark may notify for the wallet seed [parent] while the app is
  /// locked. A bool about the policy; it reads no seed and no session.
  @useResult
  Future<bool> mayNotifyArk(Fingerprint parent);

  /// Read choices for exactly [network], with no fallback to another network.
  /// Skips unreadable rows and marks the selection incomplete. If all rows
  /// are unreadable, returns an [UnreadableWalletFailure].
  /// Networks with no persisted representation are unsupported.
  @useResult
  Future<Result<WalletSelection, SecretFailure>> walletsForNetwork(
    Network network,
  );
}
