import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/features/replace_by_fee/domain/fee_entity.dart';
import 'package:bb_mobile/features/replace_by_fee/errors.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

@freezed
sealed class ReplaceByFeeState with _$ReplaceByFeeState {
  const factory ReplaceByFeeState({
    @Default(null) ReplaceByFeeError? error,
    @Default(null) FeeEntity? fastestFeeRate,
    @Default(null) FeeEntity? newFeeRate,
    @Default(null) String? txid,

    /// Live relay floor (mempool `minimumFee`, clamped to 0.1) so the custom
    /// bump field rejects sub-minimum rates under congestion. Null until the
    /// initial fee fetch completes → custom field falls back to the static
    /// 0.1 floor.
    @Default(null) RelativeFee? minRelay,
  }) = _ReplaceByFeeState;

  const ReplaceByFeeState._();
}
