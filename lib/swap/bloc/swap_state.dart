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
    SwapTx? swapTx,
    List<Transaction>? swapTxs,
  }) = _SwapState;
  const SwapState._();
}
