import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_url.dart';
import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

enum JoinstrIssue {
  bitcoinOnly,
  mainnetNotSupported,
  watchOnlyWallet,
  unsupportedScriptType,
  noEligibleCoin,
  coinUnavailable,
  invalidElectrumUrl,
  invalidPoolConfig,
  invalidRelayUrl,
  torUnavailable,
  coinjoinFailed,
}

class JoinstrException extends BullException {
  final JoinstrIssue issue;
  final int? denominationSat;
  final String? detail;

  JoinstrException(this.issue, {this.denominationSat, this.detail})
    : super('Joinstr: ${issue.name}');
}

/// A coinjoin pool advertised on a nostr relay.
class JoinstrPool {
  final String id;

  /// Canonical JSON, passed back to the bindings to join.
  final String rawJson;
  final int denominationSat;
  final int peers;

  /// When the pool expires, as a unix timestamp in seconds (absolute, not a
  /// duration).
  final int expiresAtUnixSec;
  final String relay;
  final int feeRateSatPerVb;
  final String publicKey;

  const JoinstrPool({
    required this.id,
    required this.rawJson,
    required this.denominationSat,
    required this.peers,
    required this.expiresAtUnixSec,
    required this.relay,
    required this.feeRateSatPerVb,
    required this.publicKey,
  });

  /// Seconds until the pool expires relative to [now], clamped at zero.
  int secondsUntilExpiry(DateTime now) =>
      Joinstr.secondsUntilExpiry(expiresAtUnixSec, now);
}

abstract final class Joinstr {
  /// A joinstr input must satisfy
  /// `denomination + 500 <= value <= denomination + 5000`, enforced by every
  /// other peer in `CoinJoin::add_input`. A coin outside this window is
  /// rejected after we have already published a signature over it, so the
  /// window is checked here before anything is signed.
  static const int minInputSurplusSat = 500;
  static const int maxInputSurplusSat = 5000;

  /// Derivation indexes scanned on each branch when listing coins.
  static const int scanDepth = 100;

  /// Mainnet is withheld until the bindings can route nostr and electrum
  /// traffic over Tor. Joining a pool over clearnet reveals the joining IP
  /// alongside the outpoint being mixed, which defeats the point.
  static const bool mainnetSupported = false;

  static bool isEligibleCoin({
    required int valueSat,
    required int denominationSat,
  }) =>
      valueSat >= denominationSat + minInputSurplusSat &&
      valueSat <= denominationSat + maxInputSurplusSat;

  /// The surplus (input value above the denomination) reserved to cover fees,
  /// clamped to the window every other peer enforces.
  static int surplusForFeeRate(int feeRateSatPerVb) =>
      (feeRateSatPerVb * 100).clamp(minInputSurplusSat, maxInputSurplusSat);

  /// When creating a pool the denomination follows the chosen input: it is the
  /// coin's value minus the fee surplus, so the coin is eligible by
  /// construction. Null when the coin is too small to leave a positive
  /// denomination.
  static int? deriveDenominationSat({
    required int coinValueSat,
    required int feeRateSatPerVb,
  }) {
    final denom = coinValueSat - surplusForFeeRate(feeRateSatPerVb);
    return denom > 0 ? denom : null;
  }

  /// Splits a stored electrum url into the address and port the bindings
  /// take, via the electrum module's canonical [ElectrumUrl] parse.
  ///
  /// The `ssl://` prefix is deliberately preserved: joinstr only negotiates TLS
  /// when the address starts with it, so stripping the scheme would silently
  /// downgrade an SSL-only server such as `:50002` to plaintext.
  static ({String address, int port}) parseElectrumUrl(String url) {
    final parsed = ElectrumUrl.tryParse(url);
    if (parsed == null) {
      throw JoinstrException(JoinstrIssue.invalidElectrumUrl, detail: url);
    }
    return (
      address: parsed.useSsl ? 'ssl://${parsed.host}' : parsed.host,
      port: parsed.port,
    );
  }

  /// Seconds until [expiresAtUnixSec] relative to [now], clamped at zero.
  /// Shared by pools and rounds.
  static int secondsUntilExpiry(int expiresAtUnixSec, DateTime now) {
    final remaining = expiresAtUnixSec - now.millisecondsSinceEpoch ~/ 1000;
    return remaining > 0 ? remaining : 0;
  }

  /// Formats a remaining duration for pool tiles, e.g. "1h 5m", "12m 30s",
  /// "45s".
  static String formatRemaining(int seconds) {
    if (seconds <= 0) return '0s';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  /// Nostr relays must be reached over a websocket.
  static bool isValidRelayUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    return uri != null &&
        (uri.scheme == 'wss' || uri.scheme == 'ws') &&
        uri.host.isNotEmpty;
  }

  /// Throws unless [wallet] can take part in a coinjoin.
  ///
  /// joinstr signs with its own WPKH hot signer derived from the wallet's
  /// mnemonic at `m/84'/{0,1}'/0'`, so anything that is not a locally-signed
  /// native-segwit bitcoin wallet cannot participate.
  static void assertWalletSupported(Wallet wallet) {
    if (!wallet.isBitcoin) throw JoinstrException(JoinstrIssue.bitcoinOnly);
    if (!wallet.signsLocally) {
      throw JoinstrException(JoinstrIssue.watchOnlyWallet);
    }
    if (wallet.scriptType != ScriptType.bip84) {
      throw JoinstrException(JoinstrIssue.unsupportedScriptType);
    }
    if (!wallet.isTestnet && !mainnetSupported) {
      throw JoinstrException(JoinstrIssue.mainnetNotSupported);
    }
  }
}
