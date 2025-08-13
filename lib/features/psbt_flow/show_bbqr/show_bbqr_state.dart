import 'package:freezed_annotation/freezed_annotation.dart';

part 'show_bbqr_state.freezed.dart';

@freezed
abstract class ShowBbqrState with _$ShowBbqrState {
  const factory ShowBbqrState({
    @Default(0) int currentIndex,
    @Default([]) List<String> parts,
  }) = _ShowBbqrState;
}
