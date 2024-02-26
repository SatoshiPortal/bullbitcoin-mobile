import 'package:bb_mobile/_model/transaction.dart';
import 'package:boltz_dart/boltz_dart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'swap_state.freezed.dart';

@freezed
class SwapState with _$SwapState {
  const factory SwapState({
    @Default(true) bool creatingInvoice,
    @Default('') String errCreatingInvoice,
    @Default('') String errCreatingSwapInv,
    @Default(false) bool generatingSwapInv,
    @Default('') String errClaimingSwap,
    @Default(false) bool claimingSwapSwap,
    @Default('') String errWatchingInvoice,
    SwapTx? swapTx,
    @Default([]) List<SwapTx> listeningTxs,
    @Default([]) List<SwapTx> claimedSwapTxs,
  }) = _SwapState;
  const SwapState._();

  bool isListening(SwapTx swap) => listeningTxs.any((_) => _.id == swap.id);

  bool isListeningId(String id) => listeningTxs.any((_) => _.id == id);

  SwapStatus? showStatus(SwapTx swap) {
    final isListening = listeningTxs.any((_) => _.id == swap.id);
    if (!isListening) return swap.status?.status;
    final tx = listeningTxs.firstWhere((_) => _.id == swap.id);
    return tx.status?.status;
  }

  bool swapClaimed(SwapTx swap) => claimedSwapTxs.any((_) => _.id == swap.id);

  // bool showClaim(SwapTx swap) {
  //   final status = swap.status?.status;
  //   if (status == null) return false;
  //   return status == SwapStatus.invoicePaid;
  // }
}
