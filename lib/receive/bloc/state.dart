import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/swap/bloc/swap_cubit.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

enum ReceivePaymentNetwork { bitcoin, liquid, lightning }

@freezed
class ReceiveState with _$ReceiveState {
  const factory ReceiveState({
    @Default(true) bool loadingAddress,
    @Default('') String errLoadingAddress,
    Address? defaultAddress,
    Address? defaultLiquidAddress,
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
    @Default(ReceivePaymentNetwork.bitcoin) ReceivePaymentNetwork paymentNetwork,
    required SwapCubit swapBloc,
  }) = _ReceiveState;
  const ReceiveState._();

  String getQRStr() {
    if (paymentNetwork == ReceivePaymentNetwork.lightning) {
      if (swapBloc.state.swapTx == null) return '';
      return swapBloc.state.swapTx!.invoice;
    }

    if (savedInvoiceAmount > 0 || savedDescription.isNotEmpty) {
      final btcAmt = (savedInvoiceAmount / 100000000).toStringAsFixed(8);

      var invoice = 'bitcoin:' + defaultAddress!.address + '?amount=' + btcAmt;
      if (savedDescription.isNotEmpty) invoice = invoice + '&label=' + savedDescription;

      return invoice;
    }

    if (paymentNetwork == ReceivePaymentNetwork.bitcoin)
      return defaultAddress?.address ?? '';
    else if (paymentNetwork == ReceivePaymentNetwork.liquid)
      return defaultLiquidAddress?.address ?? '';
    else
      return defaultAddress?.address ?? '';
  }

  bool showNewRequestButton() => savedDescription.isEmpty && savedInvoiceAmount == 0;

  bool isSupported() {
    if (paymentNetwork == ReceivePaymentNetwork.bitcoin &&
        walletBloc!.state.wallet?.baseWalletType == BaseWalletType.Liquid) return false;
    if (paymentNetwork == ReceivePaymentNetwork.liquid &&
        walletBloc!.state.wallet?.baseWalletType == BaseWalletType.Bitcoin) return false;
    return true;
  }

  bool showQR(SwapTx? swapTx) {
    return (swapTx != null && paymentNetwork == ReceivePaymentNetwork.lightning) ||
        (paymentNetwork == ReceivePaymentNetwork.bitcoin ||
            paymentNetwork == ReceivePaymentNetwork.liquid);
  }

  bool isLn() => paymentNetwork == ReceivePaymentNetwork.lightning;

  bool checkIfMainWalletSelected() => walletBloc?.state.wallet?.mainWallet ?? false;

  // bool _swapTxIsNotNull() => swapBloc.state.swapTx != null;

  // bool showActionButtons() =>
  //     paymentNetwork == ReceiveWalletType.secure ||
  //     (walletType == ReceiveWalletType.lightning && _swapTxIsNotNull());
}
