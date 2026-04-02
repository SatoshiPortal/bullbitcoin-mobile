import 'package:bb_mobile/core/transactions/domain/entity/transaction.dart';

/// The display/review model for a transaction.
///
/// Wraps a [Transaction] with resolved input values and optional change
/// identification. Provides computed properties for fees, send amount,
/// and recipient outputs.
class TransactionEntity {
  /// The underlying parsed transaction.
  final Transaction transaction;

  /// Resolved input values — all inputs with satoshi values populated.
  /// For wallet-built txs: values come from the local DB.
  /// For external txs: values resolved by fetching parent txs via Electrum.
  final List<ResolvedInput> resolvedInputs;

  /// The index of the change output, if known.
  /// Null for external transactions where we cannot identify change.
  final int? changeOutputIndex;

  const TransactionEntity({
    required this.transaction,
    required this.resolvedInputs,
    this.changeOutputIndex,
  });

  // --- Computed properties ---

  /// Total value of all resolved inputs in satoshis.
  int get totalInputsSat =>
      resolvedInputs.fold<int>(0, (sum, input) => sum + input.valueSat);

  /// Total value of all outputs in satoshis.
  int get totalOutputsSat => transaction.totalOutputsSat;

  /// Transaction fee in satoshis (inputs - outputs).
  int get feeSat => totalInputsSat - totalOutputsSat;

  /// Fee rate in sat/vbyte, or null if vsize is zero.
  double? get feeRate =>
      transaction.vsize > 0 ? feeSat / transaction.vsize : null;

  /// Whether the change output is known.
  bool get hasChange => changeOutputIndex != null;

  /// The change amount in satoshis, if change output is known.
  int? get changeAmountSat =>
      hasChange ? transaction.outputs[changeOutputIndex!].valueSat : null;

  /// Send amount = total outputs minus change.
  /// Null if change is unknown (external transaction).
  int? get sendAmountSat =>
      hasChange ? totalOutputsSat - changeAmountSat! : null;

  /// Recipient outputs = all non-change outputs.
  /// If change is unknown, all outputs are shown.
  List<TxOutput> get recipientOutputs => hasChange
      ? transaction.outputs.where((o) => o.index != changeOutputIndex).toList()
      : transaction.outputs;

  /// The change output, if known.
  TxOutput? get changeOutput =>
      hasChange ? transaction.outputs[changeOutputIndex!] : null;

  /// The transaction ID.
  String get txid => transaction.txid;

  /// The virtual size in vbytes.
  int get vsize => transaction.vsize;
}

/// A resolved input with its value populated.
class ResolvedInput {
  /// The value in satoshis of this input.
  final int valueSat;

  /// The txid of the parent transaction.
  final String previousTxId;

  /// The vout index in the parent transaction.
  final int previousVout;

  /// The address this input spends from, if decodable.
  /// Populated from the parent transaction's output address.
  final String? address;

  const ResolvedInput({
    required this.valueSat,
    required this.previousTxId,
    required this.previousVout,
    this.address,
  });
}
