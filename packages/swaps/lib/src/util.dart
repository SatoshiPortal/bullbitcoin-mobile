import 'package:bolt11_decoder/bolt11_decoder.dart';
import 'package:crypto/crypto.dart';

/// Proof-of-payment check for submarine swaps: true only when [preimage]
/// (hex) hashes to the payment hash committed in [invoice]. Anything
/// unparseable fails closed — a preimage we cannot verify is a preimage we
/// must not act on.
bool preimageMatchesInvoice({
  required String preimage,
  required String invoice,
}) {
  try {
    final paymentHash =
        Bolt11PaymentRequest(
              invoice.trim().toLowerCase(),
            ).tags.firstWhere((t) => t.type == 'payment_hash').data
            as String;
    final bytes = <int>[
      for (var i = 0; i + 2 <= preimage.length; i += 2)
        int.parse(preimage.substring(i, i + 2), radix: 16),
    ];
    if (preimage.length != 64 || bytes.length != 32) return false;
    final digest = sha256.convert(bytes).toString();
    return digest.toLowerCase() == paymentHash.toLowerCase();
  } catch (_) {
    return false;
  }
}

double calculatePercentage(num amount, num fee) {
  if (amount == 0) return 0.0;
  final percent = (fee / amount) * 100;
  return double.parse(percent.toStringAsFixed(2));
}

class StringFormatting {
  static String truncateMiddle(
    String input, {
    int head = 8,
    int tail = 8,
    String placeholder = '...',
  }) {
    if (input.length <= head + tail + placeholder.length) return input;
    return '${input.substring(0, head)}$placeholder${input.substring(input.length - tail)}';
  }
}

class ConversionConstants {
  static final satsAmountOfOneBitcoin = BigInt.from(100000000);
}

/// Mirrors the app's wallet network enum so engine call sites read the same.
enum Network {
  bitcoinMainnet,
  bitcoinTestnet,
  liquidMainnet,
  liquidTestnet;

  factory Network.fromEnvironment({
    required bool isTestnet,
    required bool isLiquid,
  }) => isLiquid
      ? (isTestnet ? Network.liquidTestnet : Network.liquidMainnet)
      : (isTestnet ? Network.bitcoinTestnet : Network.bitcoinMainnet);

  bool get isLiquid => this == liquidMainnet || this == liquidTestnet;
  bool get isBitcoin => !isLiquid;
  bool get isTestnet => this == bitcoinTestnet || this == liquidTestnet;
  bool get isMainnet => !isTestnet;
}

/// One resolved electrum server for a single attempt. Produced by the
/// electrum runner the app injects into the repository.
class ElectrumConnection {
  final String url;
  final bool validateDomain;
  final int timeout;

  const ElectrumConnection({
    required this.url,
    required this.validateDomain,
    required this.timeout,
  });
}

/// The wallet facts the engine acts on: a transaction's presence, direction
/// and inputs. `isIncoming` is load-bearing — an on-chain settle is only
/// accepted when the spender PAYS the wallet, never for the wallet's own
/// outgoing/change spend. `spendsTxIds` (the previous txids of the tx's
/// inputs) lets a refund-side settle additionally require that the candidate
/// actually spends OUR lockup transaction, not some other tx a hostile
/// backend pointed at.
class SwapWalletTx {
  final String txId;
  final bool isIncoming;
  final List<String> spendsTxIds;

  const SwapWalletTx({
    required this.txId,
    required this.isIncoming,
    this.spendsTxIds = const [],
  });
}

class SwapWalletInfo {
  final String id;
  final bool isLiquid;
  final bool isDefault;
  final String fingerprint;

  const SwapWalletInfo({
    required this.id,
    required this.isLiquid,
    this.isDefault = false,
    this.fingerprint = '',
  });
}

/// Runs [operation] against the app's active electrum servers in priority
/// order (custom-if-set else defaults, never mixing tiers — the app's
/// privacy rule stays behind the app's implementation).
abstract class ElectrumRunner {
  Future<T> run<T>({
    required bool isLiquid,
    required bool isTestnet,
    required Future<T> Function(ElectrumConnection connection) operation,
    bool Function(Object error)? isTransient,
  });

  /// Whether the user configured their own servers for this network. A
  /// lookup that would leave the user's servers (a third-party explorer)
  /// must not run when this is true. Implementations answer true when they
  /// cannot tell.
  Future<bool> usesCustomServers({
    required bool isLiquid,
    required bool isTestnet,
  });
}

/// What our own chain backend answered to a lockup broadcast.
sealed class LockupBroadcast {
  const LockupBroadcast();
}

final class LockupAccepted extends LockupBroadcast {
  final String txid;

  const LockupAccepted(this.txid);
}

/// The transaction is already in a block.
final class LockupAlreadyInChain extends LockupBroadcast {
  const LockupAlreadyInChain();
}

/// The node refused the transaction (invalid, conflicting, underpaying).
final class LockupRejected extends LockupBroadcast {
  const LockupRejected();
}

/// No answer we can rely on: it may or may not have been relayed.
final class LockupOutcomeUnknown extends LockupBroadcast {
  const LockupOutcomeUnknown();
}

/// The user's own chain backend (their Electrum servers), used to settle a
/// lockup whose broadcast outcome is unknown. Never a third-party explorer.
abstract class LockupChain {
  /// The txid of our signed lockup before it is broadcast. Null when it
  /// cannot be computed locally (Liquid).
  Future<String?> txidOf({required String signedTx, required bool isLiquid});

  /// Whether the servers hold our signed lockup [signedTx] under [txid], in
  /// the mempool or a block: one Electrum lookup, never a wallet sync. False
  /// when the server does not know [txid] or holds a different transaction
  /// under it.
  Future<bool> isKnown({
    required String txid,
    required String signedTx,
    required bool isLiquid,
    required bool isTestnet,
  });

  /// Broadcasts our already-signed lockup: a finalized PSBT (base64) on
  /// Bitcoin, a signed PSET on Liquid.
  Future<LockupBroadcast> broadcast({
    required String signedTx,
    required bool isLiquid,
    required bool isTestnet,
  });
}

class SwapsException implements Exception {
  final String message;

  SwapsException(this.message);

  @override
  String toString() => message;
}

/// The amount is outside the provider's current limits.
class SwapsAmountOutOfLimitsException implements Exception {
  final int minSat;
  final int maxSat;

  const SwapsAmountOutOfLimitsException({
    required this.minSat,
    required this.maxSat,
  });
}

/// A swap for the same payment already holds or is confirming a lockup.
class SwapInProgressException implements Exception {
  const SwapInProgressException();
}

/// A call to the Boltz backend failed. [kind] is boltz-client's error
/// variant name; [statusCode] is set only when Boltz answered with a non-2xx
/// status, so a null code with an `HTTP`/`IO` kind means no answer at all.
class BoltzApiException implements Exception {
  final String kind;
  final String message;
  final int? statusCode;

  BoltzApiException({required this.kind, required this.message})
    : statusCode = kind == 'HTTPStatusNotSuccess'
          ? int.tryParse(_statusPattern.firstMatch(message)?.group(1) ?? '')
          : null;

  static final _statusPattern = RegExp(r'HTTP Status Not Success: (\d{3})');

  bool get isUnreachable => switch (statusCode) {
    null => kind == 'HTTP' || kind == 'IO' || kind == 'WebSocket',
    final code => code >= 500 || code == 418,
  };

  @override
  String toString() => message;
}
