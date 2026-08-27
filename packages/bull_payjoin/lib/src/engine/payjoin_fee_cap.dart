import 'package:bull_payjoin/src/domain/payjoin_ports.dart';
import 'package:bull_payjoin/src/engine/payjoin_constants.dart';
import 'package:primitives/primitives.dart';

/// Caps how much of the receiver's own money a sender can push into miner fees,
/// tracking the live network rate so the cap is neither too tight to accept a
/// legitimate payjoin nor loose enough to be worth attacking.
///
/// See [PayjoinConstants.maxFeeRateMultiplier] for the full rationale, and
/// [PayjoinConstants.minMaxFeeRateSatPerVb] for why the result is clamped even
/// though it comes from our own fee source.
///
/// A fee-source failure falls back to the floor rather than failing the receive:
/// the floor is the conservative end of the range, so degrading here costs at
/// worst a declined payjoin, never a larger burn.
Future<int> receiverMaxFeeRateSatPerVb(
  PayjoinFeesPort fees,
  BitcoinNetwork network,
) async {
  try {
    final fastest = await fees.fastestFeeRate(network: network);
    return (fastest.satsPerVbyte * PayjoinConstants.maxFeeRateMultiplier)
        .ceil()
        .clamp(
          PayjoinConstants.minMaxFeeRateSatPerVb,
          PayjoinConstants.maxMaxFeeRateSatPerVb,
        );
  } catch (_) {
    return PayjoinConstants.minMaxFeeRateSatPerVb;
  }
}
