/// One input of a decoded Liquid transaction.
final class LiquidTransactionInput {
  final String txid;
  final int vout;
  final int sequence;
  final bool isPegin;

  const LiquidTransactionInput({
    required this.txid,
    required this.vout,
    required this.sequence,
    required this.isPegin,
  });
}

/// One output of a decoded Liquid transaction. A confidential [valueSat] or
/// [asset] the transaction does not reveal stays `null`, never zero.
final class LiquidTransactionOutput {
  final String scriptHex;
  final String? asset;
  final BigInt? valueSat;

  const LiquidTransactionOutput({
    required this.scriptHex,
    required this.asset,
    required this.valueSat,
  });
}

/// A Liquid transaction decoded without a wallet.
final class DecodedLiquidTransaction {
  final String txid;
  final int version;
  final int locktime;
  final BigInt vsize;
  final BigInt weight;

  /// The explicit fee output total, in the policy asset.
  final BigInt feeSat;
  final List<LiquidTransactionInput> inputs;
  final List<LiquidTransactionOutput> outputs;

  DecodedLiquidTransaction({
    required this.txid,
    required this.version,
    required this.locktime,
    required this.vsize,
    required this.weight,
    required this.feeSat,
    required List<LiquidTransactionInput> inputs,
    required List<LiquidTransactionOutput> outputs,
  }) : inputs = List.unmodifiable(inputs),
       outputs = List.unmodifiable(outputs);
}
