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
  poolNotFound,
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
  int secondsUntilExpiry(DateTime now) {
    final remaining = expiresAtUnixSec - now.millisecondsSinceEpoch ~/ 1000;
    return remaining > 0 ? remaining : 0;
  }
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

  /// Index of the cheapest coin that can fund a [denominationSat] pool, or
  /// null when no coin falls inside the window.
  static int? selectEligibleCoin({
    required List<int> coinValuesSat,
    required int denominationSat,
  }) {
    int? best;
    for (var i = 0; i < coinValuesSat.length; i++) {
      final value = coinValuesSat[i];
      if (!isEligibleCoin(valueSat: value, denominationSat: denominationSat)) {
        continue;
      }
      if (best == null || value < coinValuesSat[best]) best = i;
    }
    return best;
  }

  /// Splits a stored electrum url into the address and port the bindings take.
  ///
  /// The `ssl://` prefix is deliberately preserved: joinstr only negotiates TLS
  /// when the address starts with it, so stripping the scheme would silently
  /// downgrade an SSL-only server such as `:50002` to plaintext.
  static ({String address, int port}) parseElectrumUrl(String url) {
    final trimmed = url.trim();
    final schemeEnd = trimmed.indexOf('://');
    final scheme = schemeEnd == -1
        ? ''
        : trimmed.substring(0, schemeEnd).toLowerCase();
    final hostPort = schemeEnd == -1
        ? trimmed
        : trimmed.substring(schemeEnd + 3);

    final colon = hostPort.lastIndexOf(':');
    if (colon <= 0 || colon == hostPort.length - 1) {
      throw JoinstrException(JoinstrIssue.invalidElectrumUrl, detail: url);
    }

    final host = hostPort.substring(0, colon);
    final port = int.tryParse(hostPort.substring(colon + 1));
    if (port == null || port < 1 || port > 65535) {
      throw JoinstrException(JoinstrIssue.invalidElectrumUrl, detail: url);
    }

    return (address: scheme == 'ssl' ? 'ssl://$host' : host, port: port);
  }

  /// The bindings take the pool denomination as BTC in a `f64`.
  static double denominationBtc(int denominationSat) => denominationSat / 1e8;

  /// Matches the denomination input rule used by joinstr-kmp and
  /// floresta_wallet: up to 8 integer digits and up to 8 decimal places.
  static final RegExp denominationBtcPattern = RegExp(r'^\d{0,8}(\.\d{0,8})?$');

  /// Parses a BTC amount typed by the user into satoshis without a float
  /// round trip. Returns null when the text is not a positive amount matching
  /// [denominationBtcPattern].
  static int? parseDenominationBtcToSat(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || !denominationBtcPattern.hasMatch(trimmed)) {
      return null;
    }
    final parts = trimmed.split('.');
    final intPart = parts[0].isEmpty ? '0' : parts[0];
    final fracPart = parts.length > 1 ? parts[1].padRight(8, '0') : '';
    final sats =
        int.parse(intPart) * 100000000 +
        (fracPart.isEmpty ? 0 : int.parse(fracPart));
    return sats > 0 ? sats : null;
  }

  /// Renders satoshis as a BTC string with trailing zeros trimmed, e.g.
  /// 100000 -> "0.001".
  static String formatBtc(int sat) {
    final whole = sat ~/ 100000000;
    final frac = (sat % 100000000).toString().padLeft(8, '0');
    final trimmedFrac = frac.replaceFirst(RegExp(r'0+$'), '');
    return trimmedFrac.isEmpty ? '$whole' : '$whole.$trimmedFrac';
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
