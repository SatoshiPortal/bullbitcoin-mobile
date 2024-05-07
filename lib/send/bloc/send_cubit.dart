import 'dart:async';

import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/bip21.dart';
import 'package:bb_mobile/_pkg/boltz/swap.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/send/bloc/send_state.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SendCubit extends Cubit<SendState> {
  SendCubit({
    required Barcode barcode,
    WalletBloc? walletBloc,
    required WalletTx walletTx,
    required FileStorage fileStorage,
    required NetworkCubit networkCubit,
    required CurrencyCubit currencyCubit,
    required bool openScanner,
    required HomeCubit homeCubit,
    required bool defaultRBF,
    required SwapBoltz swapBoltz,
  })  : _homeCubit = homeCubit,
        _networkCubit = networkCubit,
        _currencyCubit = currencyCubit,
        _walletTx = walletTx,
        _fileStorage = fileStorage,
        _barcode = barcode,
        _swapBoltz = swapBoltz,
        super(SendState(selectedWalletBloc: walletBloc)) {
    emit(
      state.copyWith(
        disableRBF: !defaultRBF,
        selectedWalletBloc: walletBloc,
      ),
    );

    if (openScanner) scanAddress();
  }

  final Barcode _barcode;
  final FileStorage _fileStorage;
  final WalletTx _walletTx;
  final SwapBoltz _swapBoltz;

  final NetworkCubit _networkCubit;
  final CurrencyCubit _currencyCubit;
  final HomeCubit _homeCubit;

  // Destination is either Bitcoin or Lightning
  //
  // Check if BIP21 contains a Bolt 11
  // If contains a Bolt 11 invoice, check if Instant Payment Wallet has enough balance
  // If Instant Payment Wallet does not have enough balance
  // Check if a fiat account has enough balance
  // If fiat account has enough balance, use the fiat account for a Lightning transaction
  // If no fiat account has enough balance, check if Secure Bitcoin Wallet has enough balance
  // Check if another Bitcoin wallet has enough balance
  // If no Bitcoin wallet has enough balance, return error message
  void updateAddress(String? addr) async {
    emit(state.copyWith(errScanningAddress: '', scanningAddress: true));
    final address = addr ?? state.address;
    final (paymentNetwork, err) = state.getPaymentNetwork(address);
    if (err != null) {
      emit(
        state.copyWith(
          errScanningAddress: err.toString(),
          scanningAddress: false,
          address: '',
          note: '',
        ),
      );
      _currencyCubit.updateAmountDirect(0);
      resetWalletSelection();
      return;
    }

    emit(state.copyWith(paymentNetwork: paymentNetwork));

    switch (paymentNetwork!) {
      case AddressNetwork.bip21Bitcoin:
        final bip21Obj = bip21.decode(address);
        final newAddress = bip21Obj.address;
        emit(state.copyWith(address: newAddress));
        final amount = bip21Obj.options['amount'] as num?;
        if (amount != null) {
          _currencyCubit.btcToCurrentTempAmount(amount.toDouble());
          final amountInSats = (amount * 100000000).toInt();
          _currencyCubit.updateAmountDirect(amountInSats);
          emit(state.copyWith(tempAmt: amountInSats));
        }
        final label = bip21Obj.options['label'] as String?;
        if (label != null) {
          emit(state.copyWith(note: label));
        }
      case AddressNetwork.bip21Liquid:
        final bip21Obj = bip21.decode(
          address.replaceFirst('liquidnetwork:', 'bitcoin'),
        );
        final newAddress = bip21Obj.address;
        emit(state.copyWith(address: newAddress));
        final amount = bip21Obj.options['amount'] as num?;
        if (amount != null) {
          _currencyCubit.btcToCurrentTempAmount(amount.toDouble());
          final amountInSats = (amount * 100000000).toInt();
          _currencyCubit.updateAmountDirect(amountInSats);
          emit(state.copyWith(tempAmt: amountInSats));
        }
        final label = bip21Obj.options['label'] as String?;
        if (label != null) {
          emit(state.copyWith(note: label));
        }
      case AddressNetwork.lightning:
        final (inv, errInv) = await _swapBoltz.decodeInvoice(invoice: address);
        if (errInv != null) {
          emit(state.copyWith(errScanningAddress: errInv.toString()));
          return;
        }
        emit(state.copyWith(invoice: inv));
        await _processLnInvoice();
      case AddressNetwork.bitcoin:
      case AddressNetwork.liquid:
        emit(state.copyWith(address: address));
    }

    emit(state.copyWith(scanningAddress: false));
  }

  void selectWallets() {
    if (state.paymentNetwork == null) return;
    switch (state.paymentNetwork!) {
      case AddressNetwork.bip21Bitcoin:
        _processBitcoinAddress();
      case AddressNetwork.bip21Liquid:
        _processLiquidAddress();
      case AddressNetwork.lightning:
        _processLnInvoice();
      case AddressNetwork.bitcoin:
        _processBitcoinAddress();
      case AddressNetwork.liquid:
        _processLiquidAddress();
    }
  }

  // Only LN
  //
  // Check if Instant Payment Wallet has enough balance
  // Check if a fiat account has enough balance (Buy Bitcoin Order)
  // If more than one fiat account has enough balance, choose whichever is preferred currency
  // Check if Secure Bitcoin Wallet has enough balance (BTC -> LN swap)
  // Check if another Bitcoin wallet has enough balance
  // If more than one secondary Bitcoin wallet has enough balance, choose whichever has the highest balance
  // If nothing has enough balance, return error message
  Future _processLnInvoice() async {
    final amt = state.invoice!.getAmount();
    final wallets = _homeCubit.state.walletsWithEnoughBalance(
      amt,
      _networkCubit.state.getBBNetwork(),
      onlyMain: true,
    );
    if (wallets.isEmpty) {
      emit(
        state.copyWith(
          errScanningAddress: 'No wallet with enough balance',
        ),
      );
      resetWalletSelection();
      return;
    }

    final selectWallet = state.selectLiqThenSecThenOtherBtc(wallets);
    emit(
      state.copyWith(
        selectedWalletBloc: selectWallet,
        enabledWallets: wallets.map((_) => _.state.wallet!.id).toList(),
      ),
    );

    updateShowSend();
  }

  // Check if Secure Bitcoin Wallet has enough balance
  // Check if another Bitcoin wallet has enough balance
  // If more than one secondary Bitcoin wallet has enough balance, choose whichever has the highest balance
  // Check if a fiat account has enough balance (Buy Bitcoin Order)
  // If more than one fiat account has enough balance, choose whichever is preferred currency
  // Check if Instant Payments Wallet has enough balance (L-BTC -> BTC swap)
  // If nothing has enough balance, return error message
  Future _processBitcoinAddress() async {
    final amount = _currencyCubit.state.amount;
    final wallets = _homeCubit.state.walletsWithEnoughBalance(
      amount,
      _networkCubit.state.getBBNetwork(),
      onlyBitcoin: true,
    );
    if (wallets.isEmpty) {
      emit(
        state.copyWith(
          errScanningAddress: 'No wallet with enough balance',
        ),
      );
      resetWalletSelection();
      return;
    }

    final selectWallet = state.selectMainBtcThenOtherHighestBalBtc(wallets);
    emit(
      state.copyWith(
        selectedWalletBloc: selectWallet,
        enabledWallets: wallets.map((_) => _.state.wallet!.id).toList(),
      ),
    );

    updateShowSend();
  }

  // Check if Instant Payment Wallet has enough balance
  // Check if a fiat account has enough balance (Buy Bitcoin Order)
  // If more than one fiat account has enough balance, choose whichever is preferred currency
  // Check if Secure Bitcoin Wallet has enough balance (BTC -> L-BTC swap)
  // Check if another Bitcoin wallet has enough balance
  // If more than one secondary Bitcoin wallet has enough balance, choose whichever has the highest balance
  // If nothing has enough balance, return error message
  Future _processLiquidAddress() async {
    final amount = _currencyCubit.state.amount;
    final wallets = _homeCubit.state.walletsWithEnoughBalance(
      amount,
      _networkCubit.state.getBBNetwork(),
      onlyLiquid: true,
    );
    if (wallets.isEmpty) {
      emit(
        state.copyWith(
          errScanningAddress: 'No wallet with enough balance',
        ),
      );
      resetWalletSelection();
      return;
    }

    emit(
      state.copyWith(
        selectedWalletBloc: wallets.first,
        enabledWallets: wallets.map((_) => _.state.wallet!.id).toList(),
      ),
    );

    updateShowSend();
  }

  void resetWalletSelection() => emit(
        state.copyWith(
          enabledWallets: [],
          selectedWalletBloc: null,
          paymentNetwork: null,
        ),
      );

  void updateWalletBloc(WalletBloc walletBloc) {
    emit(state.copyWith(selectedWalletBloc: walletBloc));
    updateShowSend(force: true);
  }

  void updateShowSend({bool force = false}) {
    if (state.selectedWalletBloc == null) {}
    final amount = _currencyCubit.state.amount;
    emit(state.copyWith(errSending: ''));
    if (amount == 0) {
      emit(state.copyWith(showSendButton: false));
      return;
    }
    if (state.selectedUtxos.isNotEmpty) {
      final hasEnoughCoinns = state.selectedAddressesHasEnoughCoins(amount);
      emit(state.copyWith(showSendButton: hasEnoughCoinns));
      if (!hasEnoughCoinns)
        emit(
          state.copyWith(
            errSending: 'Selected UTXOs do not cover Transaction Amount & Fees',
          ),
        );
      return;
    }
    if (amount == 0) {
      emit(state.copyWith(showSendButton: false));
      return;
    }

    if (force) {
      final enoughBalance =
          state.selectedWalletBloc!.state.balanceSats() >= amount;
      emit(
        state.copyWith(
          showSendButton: enoughBalance,
          errSending: 'This wallet does not have enough balance',
        ),
      );
      return;
    }

    final walletBloc = _homeCubit.state.firstWalletWithEnoughBalance(
      amount,
      _networkCubit.state.getBBNetwork(),
    );
    if (walletBloc == null) {
      emit(
        state.copyWith(
          showSendButton: false,
          errSending: 'No wallet with enough balance',
        ),
      );
      return;
    }

    emit(state.copyWith(showSendButton: true, selectedWalletBloc: walletBloc));
  }

  void disabledDropdownClicked() {
    emit(
      state.copyWith(
        errSending:
            'Please enter payment destination and amount before selecting a wallet. We will select the best wallet for this transaction. You can override the wallet choice after.',
      ),
    );
  }

  void scanAddress() async {
    emit(state.copyWith(scanningAddress: true));
    final (address, err) = await _barcode.scan();
    if (err != null) {
      emit(
        state.copyWith(
          errScanningAddress: err.toString(),
          scanningAddress: false,
        ),
      );
      return;
    }

    updateAddress(address);
    emit(
      state.copyWith(
        scanningAddress: false,
      ),
    );
  }

  void updateAddressError(String err) =>
      emit(state.copyWith(errScanningAddress: err));

  void updateNote(String note) => emit(state.copyWith(note: note));

  void disableRBF(bool disable) => emit(state.copyWith(disableRBF: disable));

  void sendAllCoin(bool sendAll) {
    if (state.selectedWalletBloc == null) return;
    final balance = state.selectedWalletBloc!.state.balanceSats();
    emit(
      state.copyWith(
        sendAllCoin: sendAll,
      ),
    );
    _currencyCubit.updateAmountDirect(sendAll ? balance : 0);
    updateShowSend();
  }

  void utxoSelected(UTXO utxo) {
    var selectedUtxos = state.selectedUtxos.toList();

    if (selectedUtxos.containsUtxo(utxo))
      selectedUtxos = selectedUtxos.removeUtxo(utxo);
    else
      selectedUtxos.add(utxo);

    emit(state.copyWith(selectedUtxos: selectedUtxos));

    updateShowSend();
  }

  void clearSelectedUtxos() {
    emit(state.copyWith(selectedUtxos: []));
  }

  void downloadPSBTClicked() async {
    emit(
      state.copyWith(
        downloadingFile: true,
        errDownloadingFile: '',
        downloaded: false,
      ),
    );
    final psbt = state.psbt;
    if (psbt.isEmpty) {
      emit(
        state.copyWith(
          downloadingFile: false,
          errDownloadingFile: 'No PSBT',
        ),
      );
      return;
    }
    final txid = state.tx?.txid;
    if (txid == null) {
      emit(
        state.copyWith(
          downloadingFile: false,
          errDownloadingFile: 'No TXID',
        ),
      );
      return;
    }

    final errSave = await _fileStorage.savePSBT(
      psbt: psbt,
      txid: txid,
    );

    if (errSave != null) {
      emit(
        state.copyWith(
          downloadingFile: false,
          errDownloadingFile: errSave.toString(),
        ),
      );
      return;
    }

    await Future.delayed(const Duration(seconds: 1));

    emit(state.copyWith(downloadingFile: false, downloaded: true));
  }

  void confirmLn(SwapTx swapTx) {}

  void sendLn() {}

  void confirmClickedd({required int networkFees, SwapTx? swaptx}) async {
    if (state.sending) return;
    if (state.selectedWalletBloc == null) return;

    // final isLn = state.isLnInvoice();
    // if (isLn) {
    //   final walletId = state.selectedWalletBloc!.state.wallet!;
    //   final isTesnet = _networkCubit.state.testnet;
    //   final networkUrl = _networkCubit.state.getNetworkUrl();

    //   await state.swapCubit.createSubSwapForSend(
    //     wallet: walletId,
    //     invoice: state.address,
    //     amount: currencyCubit.state.amount,
    //     isTestnet: isTesnet,
    //     networkUrl: networkUrl,
    //   );
    //   await Future.delayed(const Duration(milliseconds: 500));
    //   final walletBloc = _homeCubit.state.getWalletBlocById(walletId.id);
    //   emit(state.copyWith(selectedWalletBloc: walletBloc));
    //   await Future.delayed(const Duration(milliseconds: 50));

    //   if (state.swapCubit.state.invoice == null ||
    //       state.swapCubit.state.swapTx == null) {
    //     emit(
    //       state.copyWith(
    //         sending: false,
    //         errSending: state.swapCubit.state.errCreatingSwapInv,
    //       ),
    //     );
    //     return;
    //   }
    // }

    final address = swaptx != null ? swaptx.scriptAddress : state.address;
    final fee = networkFees;
    //  isLn
    // ? networkFeesCubit.state.feesList![0]
    // : networkFeesCubit.state.feesList![networkFeesCubit.state.selectedFeesOption];

    final bool enableRbf;
    if (swaptx != null)
      enableRbf = false;
    else
      enableRbf = !state.disableRBF;

    emit(state.copyWith(sending: true, errSending: ''));

    final localWallet = state.selectedWalletBloc!.state.wallet;

    final (buildResp, err) = await _walletTx.buildTx(
      wallet: localWallet!,
      isManualSend: state.selectedUtxos.isNotEmpty,
      address: address,
      amount: swaptx != null ? swaptx.outAmount : _currencyCubit.state.amount,
      sendAllCoin: state.sendAllCoin,
      feeRate: fee.toDouble(),
      enableRbf: enableRbf,
      selectedUtxos: state.selectedUtxos,
      note: state.note,
    );
    if (err != null) {
      emit(
        state.copyWith(
          errSending: err.toString(),
          sending: false,
        ),
      );
      return;
    }

    final (wallet, tx, feeAmt) = buildResp!;
    if (wallet!.type == BBWalletType.secure ||
        wallet.type == BBWalletType.words) {
      emit(
        state.copyWith(
          sending: false,
          psbtSigned: tx!.psbt,
          psbtSignedFeeAmount: feeAmt,
          tx: tx,
          signed: true,
        ),
      );
      return;
    }

    state.selectedWalletBloc!.add(
      UpdateWallet(wallet, updateTypes: [UpdateWalletTypes.transactions]),
    );
    await Future.delayed(const Duration(seconds: 1));

    emit(
      state.copyWith(
        sending: false,
        psbt: tx!.psbt!,
        tx: tx,
      ),
    );
  }

  void sendClicked({SwapTx? swaptx}) async {
    if (state.selectedWalletBloc == null) return;
    emit(state.copyWith(sending: true, errSending: ''));

    final (wtxid, err) = await _walletTx.broadcastTxWithWallet(
      wallet: state.selectedWalletBloc!.state.wallet!,
      address: state.address,
      note: state.note,
      transaction: state.tx!,
    );
    if (err != null) {
      emit(state.copyWith(errSending: err.toString(), sending: false));
      return;
    }

    final (wallet, txid) = wtxid!;

    // final isLn = state.isLnInvoice();

    if (swaptx != null) {
      final (updatedWalletWithTxid, err2) = await _walletTx.addSwapTxToWallet(
        wallet: wallet,
        swapTx: swaptx.copyWith(txid: txid),
      );

      if (err2 != null) {
        emit(state.copyWith(errSending: err.toString()));
        return;
      }

      state.selectedWalletBloc!.add(
        UpdateWallet(
          updatedWalletWithTxid,
          updateTypes: [
            UpdateWalletTypes.addresses,
            UpdateWalletTypes.transactions,
            UpdateWalletTypes.swaps,
          ],
        ),
      );
    } else {
      state.selectedWalletBloc!.add(
        UpdateWallet(
          wallet,
          updateTypes: [
            UpdateWalletTypes.addresses,
            UpdateWalletTypes.transactions,
          ],
        ),
      );
    }
    Future.delayed(50.ms);
    state.selectedWalletBloc!.add(SyncWallet());

    emit(state.copyWith(sending: false, sent: true));
  }

  void dispose() {
    super.close();
  }
}
