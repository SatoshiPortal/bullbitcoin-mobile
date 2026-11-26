import 'package:primitives/primitives.dart';

/// A new wallet as seen by the stores that keep its properties outside the
/// inventory.
final class WalletPropertyDraft {
  final String id;
  final Network network;

  /// The local seed reference, null for a wallet without a local signer.
  final Fingerprint? secretFingerprint;

  /// The signer device name chosen at import, null when none is known.
  final String? signerDevice;

  /// A matching existing secret member may retain its backup evidence.
  final bool existingSecretMember;

  const WalletPropertyDraft({
    required this.id,
    required this.network,
    required this.secretFingerprint,
    required this.signerDevice,
    this.existingSecretMember = false,
  });
}

/// Properties kept by another owner, prepared before a wallet is published.
/// Recreated identifiers reset their properties unless their owner explicitly
/// retains matching backup evidence for an existing secret member.
///
/// Called during the inventory registration. Implementations write their own
/// state only and must not reenter the inventory.
abstract interface class WalletPropertyStore {
  Future<Result<void, Failure>> prepareWallet(WalletPropertyDraft wallet);
}
