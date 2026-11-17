import 'package:primitives/primitives.dart';

import 'ark_wallet_failure.dart';
import 'entities/ark_snapshot.dart';

/// Each native delegated renewal creates one output. Input totals conservatively
/// bound that output; fees only reduce it. Unknown caps use individual VTXOs.
Result<List<List<ArkVtxo>>, ArkWalletFailure> partitionArkRenewalBatches(
  List<ArkVtxo> vtxos,
  Sats? maximum,
) {
  if (maximum == null) {
    return Ok([
      for (final v in vtxos) [v],
    ]);
  }
  if (maximum.value == BigInt.zero ||
      vtxos.any((v) => v.amount.compareTo(maximum) > 0)) {
    return const Err(ArkValidationFailure(ArkFailureReason.invalidSelection));
  }
  final sorted = List.of(vtxos)..sort((a, b) => b.amount.compareTo(a.amount));
  final batches = <List<ArkVtxo>>[];
  final totals = <BigInt>[];
  for (final vtxo in sorted) {
    final index = totals.indexWhere(
      (total) => total + vtxo.amount.value <= maximum.value,
    );
    if (index < 0) {
      batches.add([vtxo]);
      totals.add(vtxo.amount.value);
    } else {
      batches[index].add(vtxo);
      totals[index] += vtxo.amount.value;
    }
  }
  return Ok([for (final batch in batches) List.unmodifiable(batch)]);
}
