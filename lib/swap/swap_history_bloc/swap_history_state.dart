import 'package:bb_mobile/_model/transaction.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'swap_history_state.freezed.dart';

@freezed
class SwapHistoryState with _$SwapHistoryState {
  const factory SwapHistoryState({
    @Default([]) List<(SwapTx, String)> swaps,
    @Default([]) List<Transaction> completeSwaps,
    @Default([]) List<String> refreshing,
    @Default('') String errRefreshing,
    @Default(false) bool updateSwaps,
  }) = _SwapHistoryState;
  const SwapHistoryState._();

  bool checkSwapExists(String id) =>
      swaps.any((element) => element.$1.id == id);
}
