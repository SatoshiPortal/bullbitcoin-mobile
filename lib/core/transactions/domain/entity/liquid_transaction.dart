import 'package:bb_mobile/core/transactions/domain/entity/transaction.dart';

/// Concrete Liquid transaction implementing the abstract [Transaction].
///
/// Liquid transactions differ from Bitcoin in that:
/// - Fee is provided explicitly (not computed from inputs - outputs)
/// - Outputs may have an associated asset ID
/// - Output values may be confidential (blinded)
class LiquidTransaction extends Transaction {
  @override
  final String txid;
  @override
  final int version;
  @override
  final int vsize;
  @override
  final int locktime;
  @override
  final List<LiquidTxInput> inputs;
  @override
  final List<LiquidTxOutput> outputs;

  /// The explicit fee in satoshis (Liquid provides this directly).
  final int feeSat;

  /// Transaction weight in weight units.
  final int weight;

  const LiquidTransaction({
    required this.txid,
    required this.version,
    required this.vsize,
    required this.weight,
    required this.locktime,
    required this.feeSat,
    required this.inputs,
    required this.outputs,
  });
}

/// Concrete Liquid transaction input implementing [TxInput].
class LiquidTxInput extends TxInput {
  @override
  final String previousTxId;
  @override
  final int previousVout;
  @override
  final int? valueSat;

  /// The input's sequence number.
  final int sequence;

  /// The scriptSig as a hex string.
  final String scriptSig;

  /// Witness data.
  final List<String> witness;

  /// Whether this input is a peg-in.
  final bool isPegin;

  const LiquidTxInput({
    required this.previousTxId,
    required this.previousVout,
    this.valueSat,
    required this.sequence,
    required this.scriptSig,
    required this.witness,
    required this.isPegin,
  });
}

/// Concrete Liquid transaction output implementing [TxOutput].
///
/// Liquid outputs may have confidential (blinded) values and an asset ID.
class LiquidTxOutput extends TxOutput {
  @override
  final int valueSat;
  @override
  final int index;
  @override
  final String? address;
  @override
  final String scriptPubKeyHex;

  /// The asset ID this output carries (L-BTC, USDt, etc.).
  /// Null if the asset is confidential/blinded.
  final String? asset;

  /// The nonce for confidential transactions.
  final String? nonce;

  const LiquidTxOutput({
    required this.valueSat,
    required this.index,
    this.address,
    required this.scriptPubKeyHex,
    this.asset,
    this.nonce,
  });
}
