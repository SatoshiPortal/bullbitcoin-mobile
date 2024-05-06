import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'send_state.freezed.dart';

@freezed
class SendState with _$SendState {
  const factory SendState({
    @Default('') String address,
    @Default([]) List<String> enabledWallets,
    AddressNetwork? paymentNetwork,
    @Default('') String note,
    int? tempAmt,
    @Default(false) bool scanningAddress,
    @Default('') String errScanningAddress,
    @Default(false) bool showDropdown,
    @Default(false) bool showSendButton,
    @Default(false) bool sending,
    @Default('') String errSending,
    @Default(false) bool sent,
    @Default('') String psbt,
    Transaction? tx,
    @Default(false) bool downloadingFile,
    @Default('') String errDownloadingFile,
    @Default(false) bool downloaded,
    @Default(false) bool disableRBF,
    @Default(false) bool sendAllCoin,
    @Default([]) List<UTXO> selectedUtxos,
    @Default('') String errAddresses,
    @Default(false) bool signed,
    String? psbtSigned,
    int? psbtSignedFeeAmount,
    WalletBloc? selectedWalletBloc,
    Invoice? invoice,
    // required SwapCubit swapCubit,
  }) = _SendState;
  const SendState._();

  bool walletEnabled(String walletId) => enabledWallets.contains(walletId);

  bool selectedAddressesHasEnoughCoins(int amount) {
    return calculateTotalSelected() >= amount;
  }

  bool isWatchOnly() => selectedWalletBloc?.state.wallet?.watchOnly() ?? false;

  bool isLnInvoice() => invoice != null;
  // address.startsWith('ln') && !isWatchOnly();

  int calculateTotalSelected() {
    return selectedUtxos.fold<int>(
      0,
      (previousValue, element) => previousValue + element.value,
    );
  }

  bool utxoIsSelected(UTXO utxo) => selectedUtxos.containsUtxo(utxo);

  String advancedOptionsButtonText() {
    if (selectedUtxos.isEmpty) return 'Advanced options';

    return 'Selected ${selectedUtxos.length} addresses';
  }

  // bool generatingSwap() => swapCubit.state.generatingSwapInv;

  // bool loadingWithSwap() {
  //   return generatingSwap() || sending || downloadingFile;
  // }

  String errors() {
    // if (swapCubit.state.errCreatingInvoice.isNotEmpty) {
    //   return swapCubit.state.errCreatingInvoice;
    // }

    if (errScanningAddress.isNotEmpty) {
      return errScanningAddress;
    }

    if (errDownloadingFile.isNotEmpty) {
      return errDownloadingFile;
    }

    if (errSending.isNotEmpty) {
      return errSending;
    }

    return '';
  }

  bool showButtons() {
    // if (!showSendButton && selectedWalletBloc != null) return true;
    return showSendButton;
  }

  bool checkIfMainWalletSelected() =>
      selectedWalletBloc?.state.wallet?.mainWallet ?? false;

  (AddressNetwork?, Err?) getPaymentNetwork(String address) {
    try {
      if (address.contains('bitcoin:'))
        return (AddressNetwork.bip21Bitcoin, null);
      else if (address.contains('liquidnetwork:'))
        return (AddressNetwork.bip21Liquid, null);
      else if (address.startsWith('ln'))
        return (AddressNetwork.lightning, null);
      else if (address.startsWith('lq'))
        return (AddressNetwork.liquid, null);
      else if (address.startsWith('btc')) return (AddressNetwork.bitcoin, null);
      return (null, Err('Invalid address'));
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }
}

enum AddressNetwork {
  bip21Bitcoin,
  bip21Liquid,
  lightning,
  bitcoin,
  liquid,
}
