import 'package:meta/meta.dart';

/// The NON-secret result of creating a Boltz swap. The raw swap object (with its
/// per-swap `KeyPair`) is persisted by the `swaps` feature; the master seed
/// never leaves `secrets`. This carries only what the app needs to proceed.
@immutable
class CreatedSwap {
  const CreatedSwap({
    required this.id,
    required this.scriptAddress,
    required this.outAmountSat,
    this.invoice,
  });

  final String id;
  final String scriptAddress;
  final int outAmountSat;
  final String? invoice;

  @override
  bool operator ==(Object other) =>
      other is CreatedSwap &&
      other.id == id &&
      other.scriptAddress == scriptAddress &&
      other.outAmountSat == outAmountSat &&
      other.invoice == invoice;

  @override
  int get hashCode => Object.hash(id, scriptAddress, outAmountSat, invoice);

  @override
  String toString() =>
      'CreatedSwap($id, $scriptAddress, $outAmountSat sat)';
}
