import 'package:bb_mobile/features/sp/domain/entities/sp_balance.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_sdk/bwk.dart';
import 'package:primitives/primitives.dart';

/// Maps the bwk FFI `SpBalanceView` to the domain [SpBalance], so the entity
/// stays FFI-free.
abstract final class SpBalanceMapper {
  static SpBalance toDomain(SpBalanceView view) {
    // bwk builds these from different sources: confirmedSat sums spendable
    // UTXOs, totalUnifiedSat is a payment-history running total it reports as
    // zero when the history nets out negative. Surfaced here, never rejected:
    // the snapshot that carries the balance also carries the session.
    if (view.totalUnifiedSat < view.confirmedSat) {
      log.warning('SP unified balance is below the confirmed balance');
    }
    return SpBalance(
      confirmedSat: Sats(view.confirmedSat),
      totalUnifiedSat: Sats(view.totalUnifiedSat),
    );
  }
}
