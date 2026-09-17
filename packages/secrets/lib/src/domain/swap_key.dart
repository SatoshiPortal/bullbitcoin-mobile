import 'package:primitives/primitives.dart';

/// The dedicated swap key, derived from a wallet's seed.
///
/// A scoped credential, not the wallet's own key: boltz derives every
/// per-swap key from this one plus an index, and it signs nothing on the
/// main chain. Compromising it costs swaps in flight, not the wallet.
///
/// It carries material — its own mnemonic and xprv — because boltz's API
/// takes them on every call. That is why it is derived once at setup and
/// handed to whoever owns the swap lifecycle, rather than re-derived: the
/// wallet's seed is touched a single time, here.
final class SwapKey {
  final String xprv;
  final String xpub;
  final String mnemonic;
  final Fingerprint fingerprint;
  final bool isTestnet;

  const SwapKey({
    required this.xprv,
    required this.xpub,
    required this.mnemonic,
    required this.fingerprint,
    required this.isTestnet,
  });

  @override
  String toString() => 'SwapKey($fingerprint, •••)';
}
