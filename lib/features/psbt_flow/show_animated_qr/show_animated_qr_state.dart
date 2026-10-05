import 'package:bb_mobile/features/psbt_flow/domain/psbt_flow_failure.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'show_animated_qr_state.freezed.dart';

@freezed
abstract class ShowAnimatedQrState with _$ShowAnimatedQrState {
  const factory ShowAnimatedQrState({
    @Default(0) int currentIndex,
    @Default([]) List<String> parts,
    @Default(100) int fragmentLength,
    @Default(false) bool isLoading,
    PsbtFlowFailure? failure,
  }) = _ShowAnimatedQrState;
}
