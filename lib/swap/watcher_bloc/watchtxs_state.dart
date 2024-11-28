import 'package:bb_mobile/_model/swap.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'watchtxs_state.freezed.dart';

@freezed
class WatchTxsState with _$WatchTxsState {
  const factory WatchTxsState({
    @Default('') String errClaimingSwap,
    @Default('') String errRefundingSwap,
    @Default(false) bool claimingSwap,
    @Default(false) bool refundingSwap,
    @Default('') String errWatchingInvoice,
    @Default([]) List<String> listeningTxs,
    @Default([]) List<String> claimedSwapTxs,
    @Default([]) List<String> claimingSwapTxIds,
    @Default([]) List<String> refundedSwapTxs,
    @Default([]) List<String> refundingSwapTxIds,
    SwapTx? updatedSwapTx,
    // SwapTx? txPaid,
    // Wallet? syncWallet,
  }) = _WatchTxsState;
  const WatchTxsState._();

  bool isListening(String swap) => listeningTxs.any((e) => e == swap);

  bool isListeningId(String id) => listeningTxs.any((e) => e == id);

  bool swapClaimed(String swap) => claimedSwapTxs.any((e) => e == swap);

  bool isClaiming(String swap) => claimingSwapTxIds.any((e) => e == swap);

  List<String>? addClaiming(String id) =>
      isClaiming(id) ? null : [id, ...claimingSwapTxIds];

  List<String> removeClaiming(String id) {
    final List<String> updatedList = List<String>.from(claimingSwapTxIds)
      ..remove(id);
    return updatedList;
  }

  bool swapRefunded(String swap) => refundedSwapTxs.any((e) => e == swap);

  bool isRefunding(String swap) => refundingSwapTxIds.any((e) => e == swap);

  List<String>? addRefunding(String id) =>
      isRefunding(id) ? null : [id, ...refundingSwapTxIds];

  List<String> removeRefunding(String id) {
    final List<String> updatedList = List<String>.from(refundingSwapTxIds)
      ..remove(id);
    return updatedList;
  }

  List<String> removeListeningTx(String id) {
    final List<String> updatedList = List<String>.from(listeningTxs)
      ..remove(id);
    return updatedList;
  }
}
