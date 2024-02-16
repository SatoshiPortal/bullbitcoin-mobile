import 'package:bb_mobile/_model/transaction.dart';
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
  }) = _SwapState;
  const SwapState._();

  bool isListening(Transaction tx) {
    final swap = tx.swapTx;
    if (swap == null) return false;
    return listeningTxs.any((_) => _.id == swap.id);
  }
}
