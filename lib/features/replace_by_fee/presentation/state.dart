import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/features/replace_by_fee/domain/fee_entity.dart';
import 'package:bb_mobile/features/replace_by_fee/domain/replace_by_fee_failure.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

@freezed
sealed class ReplaceByFeeState with _$ReplaceByFeeState {
  const factory ReplaceByFeeState({
    @Default(null) ReplaceByFeeFailure? failure,
    @Default(null) FeeEntity? fastestFeeRate,
    @Default(null) FeeEntity? newFeeRate,

    /// True while the custom bump field holds a below-floor or empty/invalid
    /// rate. [newFeeRate] still pins the last valid value (it doubles as the
    /// "init complete" sentinel — nulling it would collapse the screen), so
    /// this flag is what blocks [broadcast] from firing the stale rate while
    /// the field shows a rejected value.
    @Default(false) bool customFeeBelowFloor,
    @Default(null) String? txid,

    /// Live relay floor (mempool `minimumFee`, clamped to 0.1) so the custom
    /// bump field rejects sub-minimum rates under congestion. Null until the
    /// initial fee fetch completes → custom field falls back to the static
    /// 0.1 floor.
    @Default(null) RelativeFee? minRelay,
  }) = _ReplaceByFeeState;

  const ReplaceByFeeState._();
}
