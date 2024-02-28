import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/swap/bloc/swap_cubit.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

enum ReceiveWalletType { secure, lightning }

@freezed
class ReceiveState with _$ReceiveState {
  const factory ReceiveState({
    @Default(true) bool loadingAddress,
    @Default('') String errLoadingAddress,
    Address? defaultAddress,
    @Default('') String privateLabel,
    @Default(false) bool savingLabel,
    @Default('') String errSavingLabel,
    @Default(false) bool labelSaved,
    @Default(0) int savedInvoiceAmount,
    @Default('') String description,
    @Default('') String savedDescription,
    @Default(true) bool creatingInvoice,
    @Default('') String errCreatingInvoice,
    WalletBloc? walletBloc,
    @Default(ReceiveWalletType.secure) ReceiveWalletType walletType,
    required SwapCubit swapBloc,
  }) = _ReceiveState;
  const ReceiveState._();

  String getQRStr() {
    if (walletType == ReceiveWalletType.lightning) {
      if (swapBloc.state.swapTx == null) return '';
      return swapBloc.state.swapTx!.invoice;
    }

    if (savedInvoiceAmount > 0 || savedDescription.isNotEmpty) {
      final btcAmt = (savedInvoiceAmount / 100000000).toStringAsFixed(8);

      var invoice = 'bitcoin:' + defaultAddress!.address + '?amount=' + btcAmt;
      if (savedDescription.isNotEmpty) invoice = invoice + '&label=' + savedDescription;

      return invoice;
    }

    return defaultAddress!.address;
  }

  bool showNewRequestButton() => savedDescription.isEmpty && savedInvoiceAmount == 0;

  bool showQR(SwapTx? swapTx) {
    return (swapTx != null && walletType == ReceiveWalletType.lightning) ||
        (walletType == ReceiveWalletType.secure);
  }

  // bool _swapTxIsNotNull() => swapBloc.state.swapTx != null;

  // bool showActionButtons() =>
  //     walletType == ReceiveWalletType.secure ||
  //     (walletType == ReceiveWalletType.lightning && _swapTxIsNotNull());
}
