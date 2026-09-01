import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart' show Network;

/// What the send flow needs to know about the SP wallet. SP has no descriptors
/// and nothing is ever signed against it, so this is not a wallet entity.
class SpSendWallet {
  /// The unified total, which counts unconfirmed coins. bwk spends those, so
  /// this is what the amount check and the Max prefill must both work from;
  /// the confirmed balance would under-report the spend.
  final BigInt balanceSat;
  final Network network;

  const SpSendWallet({required this.balanceSat, required this.network});
}
