import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
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
    WalletBloc? selectedWalletBloc,
    Invoice? invoice,
    @Default(false) bool showSendButton,
    @Default('') String note,
    int? tempAmt,
    @Default(false) bool scanningAddress,
    @Default('') String errScanningAddress,
    // @Default(false) bool showDropdown,
    @Default(false) bool sending,
    @Default('') String errSending,
    @Default(false) bool sent,
    @Default('') String psbt,
    Transaction? tx,
    @Default(false) bool txSettled,
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
  }) = _SendState;
  const SendState._();

  bool walletEnabled(String walletId) => enabledWallets.contains(walletId);

  bool selectedAddressesHasEnoughCoins(int amount) {
    return calculateTotalSelected() >= amount;
  }

  bool isWatchOnly() => selectedWalletBloc?.state.wallet?.watchOnly() ?? false;

  bool isLnInvoice() => invoice != null;

  // String getAddressFromInvoiceOrAddress() {
  //   // if (invoice != null) return invoice!.;
  //   return address;
  // }

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

  String errors() {
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

  // bool showSendButton() {
  //   if (selectedWalletBloc != null) return true;
  //   return false;
  // }

  bool checkIfMainWalletSelected() =>
      selectedWalletBloc?.state.wallet?.mainWallet ?? false;

  (AddressNetwork?, Err?) getPaymentNetwork(String address) {
    final bitcoinMainnetPrefixes = ['1', '3', 'bc1', 'BC1'];
    final bitcoinTestnetPrefixesCase = ['m', 'n', '2', 'tb1', 'TB1'];
    final liquidMainnetPrefixesCase = ['lq1', 'LQ1', 'VJL', 'ex1', 'EX1', 'G'];
    final liquidTestnetPrefixes = ['tlq1', 'TLQ1'];
    final lightningPrefixes = [
      'lnbc',
      'LNBC',
      'lntb',
      'LNTB',
      'lnbs',
      'LNBS',
      'lnbcrt',
      'LNBCRT',
      'lightning:',
    ];
    const lightningUri = 'lightning:';
    const bitcoinUri = 'bitcoin:';
    const liquidUris = ['liquidnetwork:', 'liquidtestnet:'];

    // final lowerAddress = address.toLowerCase();
    try {
      if (address.contains(lightningUri))
        return (AddressNetwork.bip21Lightning, null);
      if (address.contains(bitcoinUri))
        return (AddressNetwork.bip21Bitcoin, null);
      else if (liquidUris.any((prefix) => address.startsWith(prefix)))
        return (AddressNetwork.bip21Liquid, null);
      else if (lightningPrefixes.any((prefix) => address.startsWith(prefix)))
        return (AddressNetwork.lightning, null);
      else if (liquidMainnetPrefixesCase
              .any((prefix) => address.startsWith(prefix)) ||
          liquidTestnetPrefixes.any((prefix) => address.startsWith(prefix)))
        return (AddressNetwork.liquid, null);
      else if (bitcoinMainnetPrefixes
              .any((prefix) => address.startsWith(prefix)) ||
          bitcoinTestnetPrefixesCase
              .any((prefix) => address.startsWith(prefix)))
        return (AddressNetwork.bitcoin, null);
      return (null, Err('Invalid address'));
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  WalletBloc selectLiqThenSecThenOtherBtc(List<WalletBloc> blocs) {
    final liqWalletIdx = blocs.indexWhere(
      (_) =>
          _.state.wallet!.mainWallet &&
          _.state.wallet!.baseWalletType == BaseWalletType.Liquid,
    );
    if (liqWalletIdx != -1) return blocs[liqWalletIdx];

    final secWalletIdx = blocs.indexWhere(
      (_) =>
          _.state.wallet!.mainWallet &&
          _.state.wallet!.baseWalletType == BaseWalletType.Bitcoin,
    );
    if (secWalletIdx != -1) return blocs[secWalletIdx];

    blocs.sort(
      (a, b) => b.state.balanceSats().compareTo(a.state.balanceSats()),
    );

    return blocs.first;
  }

  WalletBloc selectMainBtcThenOtherHighestBalBtc(List<WalletBloc> blocs) {
    final mainWalletIdx = blocs.indexWhere(
      (_) => _.state.wallet!.mainWallet,
    );
    if (mainWalletIdx != -1) return blocs[mainWalletIdx];

    blocs.sort(
      (a, b) => b.state.balanceSats().compareTo(a.state.balanceSats()),
    );

    return blocs.first;
  }

  bool isLiquidPayment() {
    if (paymentNetwork == null) return false;
    final network = paymentNetwork!.toPaymentNetwork();
    return network == PaymentNetwork.liquid;
  }
}

enum AddressNetwork {
  bip21Bitcoin,
  bip21Liquid,
  bip21Lightning,
  lightning,
  bitcoin,
  liquid,
}

extension Payment on AddressNetwork {
  PaymentNetwork toPaymentNetwork() {
    switch (this) {
      case AddressNetwork.bip21Bitcoin:
        return PaymentNetwork.bitcoin;
      case AddressNetwork.bip21Liquid:
        return PaymentNetwork.liquid;
      case AddressNetwork.lightning:
        return PaymentNetwork.lightning;
      case AddressNetwork.bitcoin:
        return PaymentNetwork.bitcoin;
      case AddressNetwork.liquid:
        return PaymentNetwork.liquid;
      case AddressNetwork.bip21Lightning:
        return PaymentNetwork.lightning;
    }
  }
}
