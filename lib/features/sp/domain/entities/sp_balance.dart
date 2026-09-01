import 'package:primitives/primitives.dart';

/// Pure domain value object for the unified Silent Payments balance.
///
/// Two figures, both from bwk, computed differently and used for different
/// things:
///
/// [confirmedSat] is the SP balance plus each sub-account's confirmed spendable
/// coins. This is the balance the wallet displays. It is NOT a spend ceiling:
/// bwk selects unconfirmed coins too, so checking against it would refuse a
/// spend the Rust side can fund.
///
/// [totalUnifiedSat] is the SP balance plus each sub-account's payment-history
/// running total, which bwk clamps to zero when it goes negative. Unconfirmed
/// receives are in that history, so this is the figure the send amount check
/// uses as its ceiling.
///
/// Coming from different computations, they can disagree. The mapper logs a
/// total below confirmed; nothing rejects it, because the balance is built
/// inside every session snapshot and refusing one would take the whole SP
/// session down.
class SpBalance {
  final Sats confirmedSat;
  final Sats totalUnifiedSat;

  const SpBalance({required this.confirmedSat, required this.totalUnifiedSat});
}
