import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

enum JoinstrIssue {
  bitcoinOnly,
  mainnetNotSupported,
  watchOnlyWallet,
  unsupportedScriptType,
  noEligibleCoin,
  invalidElectrumUrl,
  invalidPoolConfig,
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
