import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
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
    // required bool isTestnet,
    @Default([]) List<String> listeningTxs,
    @Default([]) List<String> claimedSwapTxs,
    @Default([]) List<String> claimingSwapTxIds,
    @Default([]) List<String> refundedSwapTxs,
    @Default([]) List<String> refundingSwapTxIds,
    SwapTx? txPaid,
    Wallet? syncWallet,
  }) = _WatchTxsState;
  const WatchTxsState._();

  bool isListening(String swap) => listeningTxs.any((_) => _ == swap);

  bool isListeningId(String id) => listeningTxs.any((_) => _ == id);

  // transaction_page should read status from wallet
  // SwapStatus? showStatus(SwapTx swap) {
  //   // final isListening = listeningTxs.any((_) => _ == swap.id);
  //   return swap.status?.status;
  //   // final tx = listeningTxs.firstWhere((_) => _.id == swap.id);
  //   // return tx.status?.status;
  // }

  bool swapClaimed(String swap) => claimedSwapTxs.any((_) => _ == swap);

  bool isClaiming(String swap) => claimingSwapTxIds.any((_) => _ == swap);

  List<String>? addClaiming(String id) =>
      isClaiming(id) ? null : [id, ...claimingSwapTxIds];

  List<String> removeClaiming(String id) {
    final List<String> updatedList = List<String>.from(claimingSwapTxIds)
      ..remove(id);
    return updatedList;
  }

  bool swapRefunded(String swap) => refundedSwapTxs.any((_) => _ == swap);

  bool isRefunding(String swap) => refundingSwapTxIds.any((_) => _ == swap);

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
    // final idx = state.listeningTxs.indexWhere((element) => element == swapTx.id);
    // if (idx != -1) {
    //   final newListeningTxs =
    //       state.listeningTxs.where((element) => element != swapTx.id).toList();
    //   emit(state.copyWith(listeningTxs: newListeningTxs));
    // }
  }
}
