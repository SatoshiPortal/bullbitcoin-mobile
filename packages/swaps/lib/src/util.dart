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

/// Seed material for deriving the swap master key, handed in by the app's
/// seed layer at point of use and never stored by the engine.
class SwapSeedSource {
  final String mnemonic;
  final String fingerprint;

  const SwapSeedSource({required this.mnemonic, required this.fingerprint});
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
}

class SwapsException implements Exception {
  final String message;

  SwapsException(this.message);

  @override
  String toString() => message;
}
