import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

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
    @Default(PaymentNetwork.bitcoin) PaymentNetwork paymentNetwork,
    int? updateAddressGap,
    @Default(false) bool switchToSecure,
    @Default(false) bool switchToInstant,
    @Default(false) bool receiveFormSubmitted,

    // required SwapCubit swapBloc,
  }) = _ReceiveState;
  const ReceiveState._();

  String getAddressWithAmountAndLabel(double amount, bool isLiquid, {SwapTx? swapTx, bool isTestnet = false}) {
    final String address = getQRStr(swapTx: swapTx);

    String finalAddress = '';
    if (paymentNetwork == PaymentNetwork.lightning || (amount == 0 && description.isEmpty)) {
      finalAddress = address;
    } else {
      if (isLiquid) {
        // Refer spec: https://github.com/ElementsProject/elements/issues/805
        final lqAssetId = isTestnet ? liquidTestnetAssetId : liquidMainnetAssetId;
        final liquidProtocol = isTestnet ? 'liquidtestnet' : 'liquidnetwork';
        finalAddress =
            '$liquidProtocol:$address?amount=${amount.toStringAsFixed(8)}${description.isNotEmpty ? '&label=$description' : ''}&assetid=$lqAssetId';
      } else {
        finalAddress =
            'bitcoin:$address?amount=${amount.toStringAsFixed(8)}${description.isNotEmpty ? '&label=$description' : ''}';
      }
    }
    return finalAddress;
  }

  String getQRStr({SwapTx? swapTx}) {
    if (paymentNetwork == PaymentNetwork.lightning) {
      if (swapTx == null) return '';
      return swapTx.invoice;
      // if (swapBloc.state.swapTx == null) return '';
      // return swapBloc.state.swapTx!.invoice;
    }

    if (savedInvoiceAmount > 0 || savedDescription.isNotEmpty) {
      final btcAmt = (savedInvoiceAmount / 100000000).toStringAsFixed(8);

      var invoice = 'bitcoin:' + defaultAddress!.address + '?amount=' + btcAmt;
      if (savedDescription.isNotEmpty) invoice = invoice + '&label=' + savedDescription;

      return invoice;
    }

    if (paymentNetwork == PaymentNetwork.bitcoin)
      return defaultAddress?.address ?? '';
    else if (paymentNetwork == PaymentNetwork.liquid)
      return defaultLiquidAddress?.address ?? '';
    else
      return defaultAddress?.address ?? '';
  }

  bool isSupported() {
    if (paymentNetwork == PaymentNetwork.bitcoin && walletBloc!.state.wallet?.baseWalletType == BaseWalletType.Liquid)
      return false;
    if (paymentNetwork == PaymentNetwork.liquid && walletBloc!.state.wallet?.baseWalletType == BaseWalletType.Bitcoin)
      return false;
    return true;
  }

  bool showQR(SwapTx? swapTx) {
    return (swapTx != null && paymentNetwork == PaymentNetwork.lightning) ||
        (paymentNetwork == PaymentNetwork.bitcoin || paymentNetwork == PaymentNetwork.liquid);
  }

  bool isLn() => paymentNetwork == PaymentNetwork.lightning;

  bool checkIfMainWalletSelected() => walletBloc?.state.wallet?.mainWallet ?? false;

  // bool _swapTxIsNotNull() => swapBloc.state.swapTx != null;

  // bool showActionButtons() =>
  //     paymentNetwork == ReceiveWalletType.secure ||
  //     (walletType == ReceiveWalletType.lightning && _swapTxIsNotNull());
}
