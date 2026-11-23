import 'package:primitives/primitives.dart' show NetworkEnv;
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
        Bolt11PaymentRequest(invoice.trim().toLowerCase()).tags
                .firstWhere((t) => t.type == 'payment_hash')
                .data
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

/// Mirrors the app's wallet network enum so engine call sites read the same.
enum Network {
  bitcoinMainnet,
  bitcoinTestnet,
  liquidMainnet,
  liquidTestnet,
  bitcoinRegtest,
  liquidRegtest;

  factory Network.fromEnvironment({
    required NetworkEnv environment,
    required bool isLiquid,
  }) => switch ((environment, isLiquid)) {
    (NetworkEnv.mainnet, false) => bitcoinMainnet,
    (NetworkEnv.mainnet, true) => liquidMainnet,
    (NetworkEnv.testnet, false) => bitcoinTestnet,
    (NetworkEnv.testnet, true) => liquidTestnet,
    (NetworkEnv.regtest, false) => bitcoinRegtest,
    (NetworkEnv.regtest, true) => liquidRegtest,
    (NetworkEnv.signet, _) => throw ArgumentError('Unsupported swap network'),
  };
  NetworkEnv get environment => switch (this) {
    bitcoinMainnet || liquidMainnet => NetworkEnv.mainnet,
    bitcoinTestnet || liquidTestnet => NetworkEnv.testnet,
    bitcoinRegtest || liquidRegtest => NetworkEnv.regtest,
  };
  bool get isLiquid =>
      this == liquidMainnet || this == liquidTestnet || this == liquidRegtest;
  bool get isBitcoin => !isLiquid;
  bool get isTestnet => environment == NetworkEnv.testnet;
  bool get isMainnet => environment == NetworkEnv.mainnet;
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
    required NetworkEnv environment,
    required Future<T> Function(ElectrumConnection connection) operation,
    bool Function(Object error)? isTransient,
  });

  /// Whether the user configured their own servers for this network. A
  /// lookup that would leave the user's servers (a third-party explorer)
  /// must not run when this is true. Implementations answer true when they
  /// cannot tell.
  Future<bool> usesCustomServers({
    required bool isLiquid,
    required NetworkEnv environment,
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
  /// The txid of our signed lockup before it is broadcast. Null when the
  /// signed transaction cannot be decoded.
  Future<String?> txidOf({required String signedTx, required bool isLiquid});

  /// Whether the servers hold our signed lockup [signedTx] under [txid], in
  /// the mempool or a block: one Electrum lookup, never a wallet sync. False
  /// when the server does not know [txid] or holds a different transaction
  /// under it.
  Future<bool> isKnown({
    required String txid,
    required String signedTx,
    required bool isLiquid,
    required NetworkEnv environment,
  });

  /// Broadcasts our already-signed lockup: a finalized PSBT (base64) on
  /// Bitcoin, a signed PSET on Liquid. Recheck [requireAdmission] after any
  /// authorization reads, immediately before admitting the broadcast. A
  /// refusal throws without submitting or clearing the pending transaction.
  Future<LockupBroadcast> broadcast({
    required String signedTx,
    required bool isLiquid,
    required NetworkEnv environment,
    void Function()? requireAdmission,
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
