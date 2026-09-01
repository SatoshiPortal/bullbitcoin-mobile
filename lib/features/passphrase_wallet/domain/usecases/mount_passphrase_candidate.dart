import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/entities/passphrase_wallet.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/passphrase_wallet_failure.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;

/// Mounts [candidate]'s public projection and hands its private material to the
/// wallet's session, the one place ownership of a passphrase seed changes hands
/// (spec 20.3 steps 8-9).
///
/// Shared by unlocking a known wallet and creating a new one so the ownership
/// rule is written once: the session keeps the material only when the mount
/// succeeded, and every other path zeroes it before returning.
Future<Result<void, PassphraseWalletFailure>> mountPassphraseCandidate({
  required WalletFacade wallets,
  required PassphraseWalletCandidate candidate,
  required int mountGeneration,
  String? label,
}) async {
  try {
    final mount = await wallets.mountPassphraseWallet(
      definition: WalletDefinition(
        walletRef: candidate.record.walletId,
        network: candidate.record.network,
        descriptor: candidate.record.descriptor,
        provenance: WalletProvenance.defaultSeedPassphrase,
      ),
      seed: candidate.seed,
      mountGeneration: mountGeneration,
      label: label,
    );
    if (mount.result.status == WalletDefinitionRestoreStatus.conflict ||
        !mount.capabilityLoaded) {
      // A conflicting definition is refused before the capability is loaded,
      // so the material is still ours to destroy.
      candidate.clear();
      return const Err(PassphraseWalletConflictFailure());
    }
    candidate.release();
    return const Ok(null);
  } on FormatException {
    candidate.clear();
    return const Err(PassphraseWalletDescriptorFailure());
  } on Exception {
    candidate.clear();
    return const Err(PassphraseWalletStorageFailure());
  }
}
