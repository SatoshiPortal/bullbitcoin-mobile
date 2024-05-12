import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:boltz_dart/boltz_dart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'swap_state.freezed.dart';

@freezed
class SwapState with _$SwapState {
  const factory SwapState({
    @Default(false) bool creatingInvoice,
    @Default('') String errCreatingInvoice,
    @Default('') String errCreatingSwapInv,
    @Default(false) bool generatingSwapInv,
    SwapTx? swapTx,
    // Invoice? invoice,
    @Default(false) bool errSmallAmt,
    double? errHighFees,
    Wallet? updatedWallet,
    AllFees? allFees,
    String? errAllFees,
  }) = _SwapState;
  const SwapState._();

  bool showWarning() {
    final errH = errHighFees;
    final errSA = errSmallAmt;
    return errH != null || errSA;
  }

  String err() {
    if (errCreatingSwapInv.isNotEmpty) return errCreatingSwapInv;
    if (errCreatingInvoice.isNotEmpty) return errCreatingInvoice;
    return '';
  }
}
