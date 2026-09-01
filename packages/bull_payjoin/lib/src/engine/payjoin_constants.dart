import 'dart:math';

abstract final class PayjoinConstants {
  static const bullBitcoinDirectoryUrl = 'https://payjoin.bullbitcoin.com';
  static const publicDirectoryUrl = 'https://payjo.in';

  /// Payjoin directories in preference order: the Bull Bitcoin directory is
  /// the default, and the public one is only used when it is unreachable
  /// (see PdkPayjoinDatasource.fetchOhttpKeyRelayAndDirectory).
  static const directoryUrls = [bullBitcoinDirectoryUrl, publicDirectoryUrl];

  static const bullBitcoinOhttpRelayUrl = 'https://ohttp.bullbitcoin.com';

  static const ohttpRelayUrlsBase = [
    bullBitcoinOhttpRelayUrl,
    'https://ohttp.achow101.com',
    'https://pj.bobspacebkk.com',
    'https://ohttp.cakewallet.com',
  ];

  /// The OHTTP relays allowed for a session on [directoryUrl], shuffled.
  ///
  /// HARD RULE: a relay run by the same operator as the directory must NEVER
  /// be used — the OHTTP privacy model assumes the relay (which sees the
  /// client IP) and the directory (which sees the payjoin mailbox) do not
  /// collude, so pairing ohttp.bullbitcoin.com with payjoin.bullbitcoin.com
  /// would let Bull Bitcoin link both ends on its own. Operator identity is
  /// approximated by the registrable domain (last two host labels), so any
  /// future *.bullbitcoin.com relay/directory pair stays excluded too. When
  /// the directory cannot be determined, fail closed: the Bull Bitcoin relay
  /// is dropped rather than risk pairing it with the Bull Bitcoin directory.
  static List<String> ohttpRelayUrlsFor(String? directoryUrl) {
    final directoryDomain = _registrableDomain(directoryUrl);
    final bullBitcoinDomain = _registrableDomain(bullBitcoinDirectoryUrl)!;
    final relays = [
      for (final relay in ohttpRelayUrlsBase)
        if (_registrableDomain(relay) != (directoryDomain ?? bullBitcoinDomain))
          relay,
    ]..shuffle(Random.secure());
    return relays;
  }

  /// Relays allowed for the session behind [bip21]: the directory is whatever
  /// the URI's `pj` endpoint points at. Used on every poll/post after session
  /// creation, where the directory choice is already baked into the URI.
  static List<String> ohttpRelayUrlsForBip21(String? bip21) {
    return ohttpRelayUrlsFor(_pjEndpoint(bip21));
  }

  // BIP21 URIs are commonly uppercased wholesale for QR efficiency, so the
  // `pj` key is matched case-insensitively.
  static String? _pjEndpoint(String? bip21) {
    final params = bip21 == null ? null : Uri.tryParse(bip21)?.queryParameters;
    if (params == null) return null;
    for (final entry in params.entries) {
      if (entry.key.toLowerCase() == 'pj') return entry.value;
    }
    return null;
  }

  static String? _registrableDomain(String? url) {
    final host = url == null ? null : Uri.tryParse(url)?.host.toLowerCase();
    if (host == null || host.isEmpty) return null;
    final parts = host.split('.');
    return parts.length <= 2 ? host : parts.sublist(parts.length - 2).join('.');
  }

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
