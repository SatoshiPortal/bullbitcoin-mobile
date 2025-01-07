import 'dart:math';

import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/swap.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/address_validation.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/utils.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:payjoin_flutter/send.dart';

part 'send_state.freezed.dart';

@freezed
class SendState with _$SendState {
  const factory SendState({
    @Default('') String address,
    @Default([]) List<String> enabledWallets,
    AddressNetwork? paymentNetwork,
    Wallet? selectedWallet,
    Invoice? invoice,
    @Default(false) bool showSendButton,
    @Default(false) bool buildingOnChain,
    @Default('') String note,
    int? tempAmt,
    double? btcTempAmt,
    String? tempStrAmt,
    @Default(false) bool scanningAddress,
    @Default('') String errScanningAddress,
    @Default(false) bool sending,
    @Default('') String errSending,
    @Default(false) bool sent,
    @Default('') String psbt,
    Transaction? tx,
    @Default(false) bool downloadingFile,
    @Default('') String errDownloadingFile,
    @Default(false) bool downloaded,
    @Default(false) bool disableRBF,
    Uri? payjoinEndpoint,
    Sender? payjoinSender,
    @Default(true) bool togglePayjoin,
    @Default(false) bool isPayjoinPostSuccess,
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

  bool isWatchOnly() => selectedWallet?.watchOnly() ?? false;

  bool isLnInvoice() => invoice != null;

  bool hasPjParam() => payjoinEndpoint != null;

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

  bool checkIfMainWalletSelected() => selectedWallet?.mainWallet ?? false;

  Future<(AddressNetwork?, Err?)> getPaymentNetwork(
    String address,
    BBNetwork network,
  ) async {
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

  Wallet selectLiqThenSecThenOtherBtc2(List<Wallet> wallets) {
    final liqWalletIdx = wallets.indexWhere(
      (_) => _.isMain() && _.isLiquid(),
    );
    if (liqWalletIdx != -1) return wallets[liqWalletIdx];

    final secWalletIdx = wallets.indexWhere(
      (_) => _.isMain() && _.isBitcoin(),
    );
    if (secWalletIdx != -1) return wallets[secWalletIdx];

    wallets.sort(
      (a, b) => b.balanceSats().compareTo(a.balanceSats()),
    );

    return wallets.first;
  }

  Wallet selectMainBtcThenOtherHighestBalBtc2(List<Wallet> blocs) {
    final mainWalletIdx = blocs.indexWhere(
      (_) => _.mainWallet,
    );
    if (mainWalletIdx != -1) return blocs[mainWalletIdx];

    blocs.sort(
      (a, b) => b.balanceSats().compareTo(a.balanceSats()),
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

    final wallet = selectedWallet!;

    if (network == PaymentNetwork.bitcoin && wallet.isLiquid()) return false;

    if (network == PaymentNetwork.liquid && wallet.isBitcoin()) return false;

    return true;
  }

  int convertBtcStringToSats(String btcAmt) {
    final split = btcAmt.split('.');
    final amountNo = int.parse(split[0]);
    final len = min(8, split[1].length);
    final amountDecimal =
        int.parse(split[1].substring(0, len)) * pow(10, 8 - len);

    final amountInSats = amountNo * 100000000 + amountDecimal;
    return amountInSats.toInt();
  }

  bool couldBeOnchainSwap() {
    if (selectedWallet == null) {
      return false;
    }
    if (selectedWallet!.isBitcoin() &&
        (paymentNetwork == AddressNetwork.liquid ||
            paymentNetwork == AddressNetwork.bip21Liquid)) {
      return true;
    }

    if (selectedWallet!.isLiquid() &&
        (paymentNetwork == AddressNetwork.bitcoin ||
            paymentNetwork == AddressNetwork.bip21Bitcoin)) {
      return true;
    }

    return false;
  }

  String getSendButtonLabel(bool sending) {
    if (couldBeOnchainSwap() == true) return 'Create Swap';

    final watchOnly = selectedWallet?.watchOnly() ?? false;
    final isLn = isLnInvoice();

    final String label = watchOnly
        ? 'Generate PSBT'
        : signed
            ? sending
                ? payjoinSender != null
                    ? 'Payjoining'
                    : 'Broadcasting'
                : payjoinSender != null
                    ? 'Confirm Payjoin'
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
