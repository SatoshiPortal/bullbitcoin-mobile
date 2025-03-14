import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/swap.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:payjoin_flutter/receive.dart';

part 'state.freezed.dart';

@freezed
class ReceiveState with _$ReceiveState {
  const factory ReceiveState({
    @Default(true) bool loadingAddress,
    @Default(true) bool isPayjoin,
    @Default('') String errLoadingAddress,
    Address? defaultAddress,
    Address? defaultLiquidAddress,
    @Default(false) bool savingLabel,
    @Default('') String errSavingLabel,
    @Default(false) bool labelSaved,
    @Default(0) int savedInvoiceAmount,
    @Default('') String description,
    @Default('') String savedDescription,
    @Default('') String payjoinEndpoint,
    Receiver? payjoinReceiver,
    @Default(true) bool creatingInvoice,
    @Default('') String errCreatingInvoice,
    Wallet? wallet,
    @Default(PaymentNetwork.bitcoin) PaymentNetwork paymentNetwork,
    int? updateAddressGap,
    @Default(false) bool switchToSecure,
    @Default(false) bool switchToInstant,
    @Default(false) bool receiveFormSubmitted,
    @Default(false) bool oneWallet,
  }) = _ReceiveState;
  const ReceiveState._();

  String getAddressWithAmountAndLabel(
    double amount,
    bool isLiquid, {
    SwapTx? swapTx,
    bool isTestnet = false,
  }) {
    final String address = getQRStr(swapTx: swapTx);

    String finalAddress = '';
    if (paymentNetwork == PaymentNetwork.lightning ||
        (amount == 0 && description.isEmpty && payjoinReceiver == null)) {
      finalAddress = address;
    } else {
      if (isLiquid) {
        final lqAssetId =
            isTestnet ? liquidTestnetAssetId : liquidMainnetAssetId;
        final liquidProtocol = isTestnet ? 'liquidtestnet' : 'liquidnetwork';
        finalAddress =
            '$liquidProtocol:$address?amount=${amount.toStringAsFixed(8)}${description.isNotEmpty ? '&label=$description' : ''}&assetid=$lqAssetId';
      } else if (payjoinReceiver != null) {
        var pjUrl = payjoinReceiver!.pjUriBuilder();
        if (amount > 0) {
          pjUrl = pjUrl.amountSats(amount: BigInt.from(amount * 100000000));
        }
        if (description.isNotEmpty) {
          pjUrl = pjUrl.label(label: description);
        }
        finalAddress = pjUrl.build().asString();
      } else {
        finalAddress =
            'bitcoin:$address?amount=${amount.toStringAsFixed(8)}${description.isNotEmpty ? '&label=$description' : ''}';
      }
    }
    return finalAddress;
  }

  String getQRStr({SwapTx? swapTx}) {
    if (swapTx?.isChainSwap() == true) {
      return swapTx!.scriptAddress;
    }
    if (paymentNetwork == PaymentNetwork.lightning && swapTx != null) {
      return swapTx.lnSwapDetails!.invoice;
    }

    if (savedInvoiceAmount > 0 || savedDescription.isNotEmpty) {
      final btcAmt = (savedInvoiceAmount / 100000000).toStringAsFixed(8);

      var invoice = 'bitcoin:${defaultAddress!.address}?amount=$btcAmt';
      if (savedDescription.isNotEmpty) {
        invoice = '$invoice&label=$savedDescription';
      }

      return invoice;
    }

    if (paymentNetwork == PaymentNetwork.bitcoin) {
      return defaultAddress?.address ?? '';
    } else if (paymentNetwork == PaymentNetwork.liquid) {
      return defaultLiquidAddress?.address ?? '';
    } else {
      return defaultAddress?.address ?? '';
    }
  }

  bool isChainSwap() {
    if (wallet == null) return false;
    if (paymentNetwork == PaymentNetwork.bitcoin && wallet!.isLiquid()) {
      return true;
    }
    if (paymentNetwork == PaymentNetwork.liquid && wallet!.isBitcoin()) {
      return true;
    }
    return false;
  }

  bool showQR(SwapTx? swapTx, {bool isChainSwap = false}) {
    if (isChainSwap == true) return swapTx != null;
    return (swapTx != null && paymentNetwork == PaymentNetwork.lightning) ||
        (paymentNetwork == PaymentNetwork.bitcoin ||
            paymentNetwork == PaymentNetwork.liquid);
  }

  bool isLn() => paymentNetwork == PaymentNetwork.lightning;

  bool checkIfMainWalletSelected() => wallet?.mainWallet ?? false;

  bool allowedSwitch(PaymentNetwork network) {
    if (!oneWallet) return true;
    if (wallet == null) return false;

    if (network == PaymentNetwork.bitcoin && wallet!.isLiquid()) return false;
    if (network == PaymentNetwork.liquid && wallet!.isBitcoin()) return false;

    return true;
  }
}
