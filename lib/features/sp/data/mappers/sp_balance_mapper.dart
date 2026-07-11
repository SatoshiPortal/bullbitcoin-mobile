import 'package:bb_mobile/features/sp/domain/entities/sp_balance.dart';
import 'package:bull_sdk/bwk.dart';

/// Maps the bwk FFI `SpBalanceView` to the domain [SpBalance], so the entity
/// stays FFI-free.
abstract final class SpBalanceMapper {
  static SpBalance toDomain(SpBalanceView view) => SpBalance(
    confirmedSat: view.confirmedSat,
    totalUnifiedSat: view.totalUnifiedSat,
  );
}
