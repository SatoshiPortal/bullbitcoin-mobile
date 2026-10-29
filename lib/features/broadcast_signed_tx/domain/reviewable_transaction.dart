import 'package:bb_mobile/core/transactions/domain/entities/liquid_transaction.dart';
import 'package:bb_mobile/core/transactions/domain/entities/transaction.dart';

/// The display/review aggregate for a transaction.
///
/// Wraps a [Transaction] with resolved input values and optional change
/// identification. Provides computed properties for fees, send amount,
/// and recipient outputs.
class ReviewableTransaction {
  /// The underlying parsed transaction.
  final Transaction transaction;

  /// Resolved input values — all inputs with satoshi values populated.
  /// For wallet-built txs: values come from the local DB.
  /// For external txs: values resolved by fetching parent txs via Electrum.
  final List<ResolvedInput> resolvedInputs;

  /// The index of the change output, if known.
  /// Null for external transactions where we cannot identify change.
  final int? changeOutputIndex;

  const ReviewableTransaction({
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

  /// Transaction fee in satoshis.
  /// For Liquid, uses the explicit fee field. For Bitcoin, computed as inputs − outputs.
  int? get feeSat {
    if (transaction is! LiquidTransaction &&
        (resolvedInputs.isEmpty ||
            resolvedInputs.length != transaction.inputs.length)) {
      return null;
    }
    final fee = switch (transaction) {
      LiquidTransaction(:final feeSat) => feeSat,
      _ => totalInputsSat - totalOutputsSat,
    };
    return fee < 0 ? null : fee;
  }

  /// Fee rate in sat/vbyte, or null if vsize is zero.
  double? get feeRate {
    final fee = feeSat;
    return transaction.vsize > 0 && fee != null
        ? fee / transaction.vsize
        : null;
  }

  bool get hasChange => changeOutput != null;
  int? get changeAmountSat => changeOutput?.valueSat;
  int? get sendAmountSat {
    final change = changeAmountSat;
    return change == null ? null : totalOutputsSat - change;
  }

  /// Recipient outputs = all non-change outputs.
  /// If change is unknown, all outputs are shown.
  List<TxOutput> get recipientOutputs => hasChange
      ? transaction.outputs.where((o) => o.index != changeOutputIndex).toList()
      : transaction.outputs;

  /// The change output, if known.
  TxOutput? get changeOutput => switch (changeOutputIndex) {
    final index? when index >= 0 && index < transaction.outputs.length =>
      transaction.outputs[index],
    _ => null,
  };

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
