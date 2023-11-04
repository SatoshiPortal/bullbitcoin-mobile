import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';
part 'state.g.dart';

@freezed
class NetworkState with _$NetworkState {
  const factory NetworkState({
    @Default(false) bool testnet,
    //
    @Default(false) bool loadingFees,
    @Default('') String errLoadingFees,
  }) = _NetworkState;
  const NetworkState._();

  factory NetworkState.fromJson(Map<String, dynamic> json) => _$NetworkStateFromJson(json);
}
