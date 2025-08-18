import 'package:freezed_annotation/freezed_annotation.dart';

part 'show_psbt_state.freezed.dart';

@freezed
abstract class ShowPsbtState with _$ShowPsbtState {
  const factory ShowPsbtState({
    @Default(false) bool isLoading,
    @Default([]) List<String> bbqrParts,
    String? error,
  }) = _ShowPsbtState;

  factory ShowPsbtState.initial() => const ShowPsbtState();
}
