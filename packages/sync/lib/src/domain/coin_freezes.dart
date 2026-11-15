import 'package:primitives/primitives.dart';

/// A user freeze. The outpoint is frozen for every wallet that holds it;
/// [origin] only attributes the freeze for BIP329 export, and is empty when
/// the freeze was imported without a known wallet.
final class FrozenOutpoint {
  final Outpoint outpoint;
  final String origin;

  const FrozenOutpoint(this.outpoint, {required this.origin});

  @override
  bool operator ==(Object other) =>
      other is FrozenOutpoint &&
      other.outpoint == outpoint &&
      other.origin == origin;

  @override
  int get hashCode => Object.hash(outpoint, origin);
}

/// A committed change of the freeze store, distinct from wallet revisions:
/// a freeze never remaps a native wallet.
final class PolicyRevision {
  final int value;

  const PolicyRevision(this.value);

  @override
  bool operator ==(Object other) =>
      other is PolicyRevision && other.value == value;

  @override
  int get hashCode => value.hashCode;
}
