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
  }) = _ReplaceByFeeState;

  const ReplaceByFeeState._();
}
