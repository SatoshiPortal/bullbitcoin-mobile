import 'package:bb_mobile/features/ark/errors.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

@freezed
sealed class ArkState with _$ArkState {
  const factory ArkState({ArkError? error, @Default(false) bool isLoading}) =
      _ArkState;
}
