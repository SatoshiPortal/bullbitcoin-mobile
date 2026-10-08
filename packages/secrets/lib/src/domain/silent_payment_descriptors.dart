import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// What a watch-only BIP352 silent payment account needs, derived from a
/// wallet's seed: the two descriptors bwk opens the account from.
///
/// A scoped credential, not the wallet's own key. The scan private key in
/// [sp] detects incoming silent payments and reveals their amounts;
/// it signs nothing and has no spend authority. Compromising it costs privacy
/// — whoever holds it sees every payment this wallet receives — not funds.
/// The spend key never leaves the package: [sp] carries its public
/// half, which every silent payment address already publishes.
///
/// [taproot] is the public BIP86 account descriptor for the taproot
/// sub-account the silent payment wallet keeps beside its silent payment
/// outputs.
///
/// Re-derive it per session rather than storing it: unlike the swap key,
/// nothing requires it to outlive the wallet session that scans with it.
final class SilentPaymentDescriptors {
  /// BIP392 `sp(<scan key WIF>,<spend public key>)`: the BIP352 scan private
  /// key at `m/352'/coin'/0'/1'/0` as a compressed WIF for the network, and
  /// the compressed spend public key at `m/352'/coin'/0'/0'/0` as 66 lowercase
  /// hex characters. No checksum.
  final String sp;

  /// `tr([<fingerprint>/86'/<coin>'/0']<xpub>/<0;1>/*)`, public only.
  final String taproot;

  final BitcoinNetwork network;

  final Fingerprint fingerprint;

  @internal
  const SilentPaymentDescriptors({
    required this.sp,
    required this.taproot,
    required this.network,
    required this.fingerprint,
  });

  /// Never widen this: a scan key that prints itself ends up in a log.
  @override
  String toString() => 'SilentPaymentDescriptors($fingerprint, •••)';
}
