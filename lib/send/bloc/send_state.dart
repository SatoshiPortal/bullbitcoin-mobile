import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/swap.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/address_validation.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/utils.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
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
    @Default(false) bool buildingOnChain,
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
    // @Default(false) bool txSettled,
    // @Default(false) bool txPaid,
    @Default(false) bool downloadingFile,
    @Default('') String errDownloadingFile,
    @Default(false) bool downloaded,
    @Default(false) bool disableRBF,
    Uri? payjoinEndpoint,
    @Default(false) bool sendAllCoin,
    @Default([]) List<UTXO> selectedUtxos,
    @Default('') String errAddresses,
    @Default(false) bool signed,
    String? psbtSigned,
    int? psbtSignedFeeAmount,
    int? onChainAbsFee,
    @Default(false) bool onChainSweep,
    @Default(false) bool oneWallet,
    @Default(false) bool drainUtxos,
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

  Future<(AddressNetwork?, Err?)> getPaymentNetwork(
    String address,
    BBNetwork network,
  ) async {
    // final bitcoinMainnetPrefixes = ['1', '3', 'bc1', 'BC1'];
    // final bitcoinTestnetPrefixesCase = ['m', 'n', '2', 'tb1', 'TB1'];
    // final liquidMainnetPrefixesCase = ['lq1', 'LQ1', 'VJL', 'ex1', 'EX1', 'G'];
    // final liquidTestnetPrefixes = ['tlq1', 'TLQ1'];
    // final lightningPrefixes = [
    //   'lnbc',
    //   'LNBC',
    //   'lntb',
    //   'LNTB',
    //   'lnbs',
    //   'LNBS',
    //   'lnbcrt',
    //   'LNBCRT',
    //   'lightning:',
    // ];
    // const lightningUri = 'lightning:';
    // const bitcoinUri = 'bitcoin:';
    // const liquidUris = ['liquidnetwork:', 'liquidtestnet:'];

    // const a = lwk.Address.new(standard: '', confidential: '', index: 1);
    // lwk.Address.validate(addressString: '');
    // boltz.DecodedInvoice.fromString(s: '');

    final lowerAddress = address.toLowerCase();

    final bdkNetwork = network == BBNetwork.Mainnet
        ? bdk.Network.bitcoin
        : bdk.Network.testnet;
    try {
      if (lowerAddress.startsWith(lightningUri)) {
        return checkIfValidBip21LightningUri(lowerAddress);
      } else if (lowerAddress.startsWith(bitcoinUri)) {
        return checkIfValidBip21BitcoinUri(
          address,
          bdkNetwork,
        );
      } else if (liquidUris.any((prefix) => lowerAddress.startsWith(prefix))) {
        return checkIfValidBip21LiquidUri(address);
      }

      final (lnSuccess, _) = await checkIfValidLightningUri(address);
      if (lnSuccess != null) {
        return (lnSuccess, null);
      }

      final (lqSuccess, _) = await checkIfValidLiquidUri(address);
      if (lqSuccess != null) {
        return (lqSuccess, null);
      }

      final (btcSuccess, _) = await checkIfValidBitcoinUri(address, bdkNetwork);
      if (btcSuccess != null) {
        return (btcSuccess, null);
      }

      if (isValidEmail(address)) {
        return (null, Err('LNURL not supported yet'));
      }

      return (null, Err('Invalid address'));
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  WalletBloc selectLiqThenSecThenOtherBtc(List<WalletBloc> blocs) {
    final liqWalletIdx = blocs.indexWhere(
      (_) => _.state.wallet!.isMain() && _.state.wallet!.isLiquid(),
    );
    if (liqWalletIdx != -1) return blocs[liqWalletIdx];

    final secWalletIdx = blocs.indexWhere(
      (_) => _.state.wallet!.isMain() && _.state.wallet!.isBitcoin(),
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

  bool allowedSwitch(PaymentNetwork network) {
    if (!oneWallet) return true;

    final wallet = selectedWalletBloc!.state.wallet;
    if (wallet == null) return false;

    if (network == PaymentNetwork.bitcoin && wallet.isLiquid()) return false;

    if (network == PaymentNetwork.liquid && wallet.isBitcoin()) return false;

    return true;
  }

  bool couldBeOnchainSwap() {
    if (selectedWalletBloc == null || selectedWalletBloc?.state.wallet == null)
      return false;
    if (selectedWalletBloc!.state.wallet!.isBitcoin() &&
        (paymentNetwork == AddressNetwork.liquid ||
            paymentNetwork == AddressNetwork.bip21Liquid)) return true;

    if (selectedWalletBloc!.state.wallet!.isLiquid() &&
        (paymentNetwork == AddressNetwork.bitcoin ||
            paymentNetwork == AddressNetwork.bip21Bitcoin)) return true;

    return false;
  }

  String getSendButtonLabel(bool sending) {
    if (couldBeOnchainSwap() == true) return 'Create Swap';

    final watchOnly = selectedWalletBloc?.state.wallet?.watchOnly() ?? false;
    final isLn = isLnInvoice();

    final String label = watchOnly
        ? 'Generate PSBT'
        : signed
            ? sending
                ? 'Broadcasting'
                : 'Confirm'
            : sending
                ? 'Building Tx'
                : !isLn
                    ? 'Send'
                    : 'Send';
    return label;
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
