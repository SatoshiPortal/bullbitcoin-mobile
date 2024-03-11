import 'package:bb_mobile/_model/transaction.dart';
import 'package:boltz_dart/boltz_dart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'watchtxs_state.freezed.dart';

@freezed
class WatchTxsState with _$WatchTxsState {
  const factory WatchTxsState({
    @Default('') String errClaimingSwap,
    @Default(false) bool claimingSwap,
    @Default('') String errWatchingInvoice,
    BoltzApi? boltzWatcher,
    @Default([]) List<String> listeningTxs,
    @Default([]) List<String> claimedSwapTxs,
    @Default([]) List<String> claimingSwapTxIds,
  }) = _WatchTxsState;
  const WatchTxsState._();

  bool isListening(SwapTx swap) => listeningTxs.any((_) => _ == swap.id);

  bool isListeningId(String id) => listeningTxs.any((_) => _ == id);

  // transaction_page should read status from wallet
  // SwapStatus? showStatus(SwapTx swap) {
  //   // final isListening = listeningTxs.any((_) => _ == swap.id);
  //   return swap.status?.status;
  //   // final tx = listeningTxs.firstWhere((_) => _.id == swap.id);
  //   // return tx.status?.status;
  // }

  bool swapClaimed(SwapTx swap) => claimedSwapTxs.any((_) => _ == swap.id);

  bool isClaiming(String swap) => claimingSwapTxIds.contains(swap);

  List<String> addClaimingTx(String id) {
    if (isClaiming(id)) return List<String>.from(claimingSwapTxIds);
    final List<String> updatedList = List<String>.from(claimingSwapTxIds)..add(id);
    return updatedList;
  }

  List<String> removeClaimingTx(String id) {
    final List<String> updatedList = List<String>.from(claimingSwapTxIds)..remove(id);
    return updatedList;
  }
}
