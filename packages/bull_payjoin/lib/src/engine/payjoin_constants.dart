import 'dart:math';

abstract final class PayjoinConstants {
  static const ohttpRelayUrlsBase = [
    'https://ohttp.achow101.com',
    'https://pj.bobspacebkk.com',
    'https://ohttp.cakewallet.com',
  ];

  static List<String> get ohttpRelayUrls {
    final relays = [...ohttpRelayUrlsBase]..shuffle(Random.secure());
    return relays;
  }

  static const directoryUrl = 'https://payjo.in';
  static const directoryPollingInterval = 5;
  static const defaultExpireAfterSec = 60 * 60 * 24;
  static const defaultMinAmountSat = 10000;

  // Bounds how much of the RECEIVER's own money a sender can push into miner
  // fees. The receiver's mandatory contribution is contributed weight x
  // max(BROADCAST_MIN, sender minfeerate), debited from our change output and
  // rejected only above contributed weight x maxEffectiveFeeRate. The sender's
  // minfeerate is attacker-controlled, so maxEffectiveFeeRate is the only thing
  // bounding the burn: at a hardcoded 10,000 sat/vB a ~100 vB contribution
  // could cost the receiver ~1,000,000 sats.
  //
  // Do NOT "fix" this by also passing a minFeeRate: the crate takes
  // max(ourMinFeeRate, senderMinFeeRate), so a floor of ours can only raise the
  // receiver's contribution, never lower it.
  //
  // Derived per session from the live fastest tier rather than hardcoded,
  // because a fixed number is either too tight in a congested mempool
  // (legitimate payjoins fail and fall back to a plain payment) or too loose in
  // a quiet one. The multiplier is the headroom for the mempool moving between
  // session creation and the request actually arriving, which can be up to
  // defaultExpireAfterSec later.
  static const int maxFeeRateMultiplier = 3;

  // Floor so a near-empty mempool doesn't produce a cap so tight that normal
  // payjoins fail, and hard ceiling so the cap stays bounded no matter what the
  // fee source reports — the mempool server is user-configurable, so it is not
  // fully trusted input. At the ceiling the worst case is ~100 vB x 100 sat/vB
  // = ~10,000 sats instead of ~1,000,000.
  static const int minMaxFeeRateSatPerVb = 20;
  static const int maxMaxFeeRateSatPerVb = 100;
}
