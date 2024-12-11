import 'dart:async';

import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/network.dart';
import 'package:bb_mobile/_model/swap.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/boltz/swap.dart';
import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/wallet/bip21.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/network_fees/bloc/networkfees_cubit.dart';
import 'package:bb_mobile/send/bloc/send_state.dart';
import 'package:bb_mobile/swap/create_swap_bloc/swap_cubit.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:boltz_dart/boltz_dart.dart' as boltz;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SendCubit extends Cubit<SendState> {
  SendCubit({
    required Barcode barcode,
    WalletBloc? walletBloc,
    required WalletTx walletTx,
    required FileStorage fileStorage,
    required NetworkCubit networkCubit,
    required NetworkFeesCubit networkFeesCubit,
    required CurrencyCubit currencyCubit,
    required bool openScanner,
    required HomeCubit homeCubit,
    required bool defaultRBF,
    required SwapBoltz swapBoltz,
    required CreateSwapCubit swapCubit,
    bool oneWallet = true,
  })  : _homeCubit = homeCubit,
        _networkCubit = networkCubit,
        _networkFeesCubit = networkFeesCubit,
        _currencyCubit = currencyCubit,
        _walletTx = walletTx,
        _fileStorage = fileStorage,
        _barcode = barcode,
        _swapBoltz = swapBoltz,
        _swapCubit = swapCubit,
        super(
          SendState(
            selectedWalletBloc: walletBloc,
            oneWallet: oneWallet,
          ),
        ) {
    emit(
      state.copyWith(
        disableRBF: !defaultRBF,
        // selectedWalletBloc: walletBloc,
      ),
    );

    if (openScanner) scanAddress();
    if (walletBloc != null) selectWallets(fromStart: true);
  }

  final Barcode _barcode;
  final FileStorage _fileStorage;
  final WalletTx _walletTx;
  final SwapBoltz _swapBoltz;

  final NetworkCubit _networkCubit;
  final NetworkFeesCubit _networkFeesCubit;
  final CurrencyCubit _currencyCubit;
  final HomeCubit _homeCubit;
  final CreateSwapCubit _swapCubit;

  void updateAddress(String? addr, {bool changeWallet = true}) async {
    if (!state.oneWallet) resetWalletSelection(changeWallet: changeWallet);
    resetErrors();
    _swapCubit.clearSwapTx();
    _swapCubit.clearErrors();
    emit(
      state.copyWith(
        errScanningAddress: '',
        scanningAddress: true,
      ),
    );
    final address = addr ?? state.address;
    final network = _networkCubit.state.getBBNetwork();
    final (paymentNetwork, err) =
        await state.getPaymentNetwork(address, network);
    if (err != null) {
      emit(
        state.copyWith(
          errScanningAddress: err.toString(),
          scanningAddress: false,
          // address: '',
          invoice: null,
          note: '',
        ),
      );
      _currencyCubit.updateAmountDirect(0);
      _currencyCubit.updateAmount('');
      resetWalletSelection(changeWallet: changeWallet);
      if (address.isEmpty) resetErrors();
      return;
    }

    if (!state.allowedSwitch(paymentNetwork!.toPaymentNetwork())) {
      emit(
        state.copyWith(
          errScanningAddress: 'Invalid address for this wallet',
        ),
      );
      return;
    }

    emit(state.copyWith(paymentNetwork: paymentNetwork));

    switch (paymentNetwork) {
      case AddressNetwork.bip21Bitcoin:
        final bip21Obj = bip21.decode(address.toLowerCase());
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
        final pjParam = bip21Obj.options['pj'] as String?;
        if (pjParam != null) {
          emit(state.copyWith(payjoinEndpoint: Uri.parse(pjParam)));
        }
      case AddressNetwork.bip21Liquid:
        final bip21Obj = bip21.decode(
          address.startsWith('liquidnetwork:')
              ? address.replaceFirst('liquidnetwork:', 'bitcoin:')
              : address.replaceFirst('liquidtestnet:', 'bitcoin:'),
        );
        final newAddress = bip21Obj.address;
        emit(state.copyWith(address: newAddress));
        final amount = bip21Obj.options['amount'] as num?;
        if (amount != null) {
          _currencyCubit.btcToCurrentTempAmount(amount.toDouble());
          final amountInSats =
              _currencyCubit.convertBtcStringToSats(amount.toString());
          // final amountInSats = (amount * 100000000).toInt();
          _currencyCubit.updateAmountDirect(amountInSats);
          emit(state.copyWith(tempAmt: amountInSats));
        }
        final label = bip21Obj.options['label'] as String?;
        if (label != null) {
          emit(state.copyWith(note: label));
        }
      case AddressNetwork.lightning:
        final boltzUrl =
            _networkCubit.state.testnet ? boltzTestnetUrl : boltzMainnetUrl;
        final (inv, errInv) = await _swapBoltz.decodeInvoice(
          invoice: address.toLowerCase(),
          boltzUrl: boltzUrl,
        );
        if (errInv != null) {
          emit(state.copyWith(errScanningAddress: errInv.toString()));
          return;
        }
        if (inv!.bip21 != null) {
          updateAddress(inv.bip21);
          return;
        }
        if (inv.getAmount() == 0) {
          emit(
            state.copyWith(
              errScanningAddress: 'Invoice must have an amount.',
            ),
          );
          return;
        }
        if (_networkCubit.state.testnet != inv.isTestnet()) {
          emit(state.copyWith(errScanningAddress: 'Network mismatch'));
          return;
        }
        _currencyCubit.updateAmountDirect(inv.getAmount());
        emit(state.copyWith(invoice: inv, address: address));

      case AddressNetwork.bip21Lightning:
        final invoice = address.toLowerCase().replaceAll('lightning:', '');
        final (inv, errInv) = await _swapBoltz.decodeInvoice(invoice: invoice);
        if (errInv != null) {
          emit(state.copyWith(errScanningAddress: errInv.toString()));
          return;
        }
        if (inv!.getAmount() == 0) {
          emit(
            state.copyWith(
              errScanningAddress: 'Invoice must have an amount.',
              invoice: inv,
              address: invoice,
            ),
          );
          return;
        }
        if (_networkCubit.state.testnet != inv.isTestnet()) {
          emit(state.copyWith(errScanningAddress: 'Network mismatch'));

          return;
        }
        _currencyCubit.updateAmountDirect(inv.getAmount());
        emit(state.copyWith(invoice: inv, address: invoice));

      case AddressNetwork.bitcoin:
        emit(state.copyWith(address: address));

      case AddressNetwork.liquid:
        emit(state.copyWith(address: address));
    }

    emit(state.copyWith(scanningAddress: false));
    if (changeWallet == true) {
      selectWallets();
    } else {
      _checkBalance();
    }
  }

  void selectWallets({bool fromStart = false}) {
    resetErrors();
    if (!fromStart) {
      if (state.paymentNetwork == null) return;
    } else {
      final isLiq = state.selectedWalletBloc!.state.isLiq();
      emit(
        state.copyWith(
          paymentNetwork:
              isLiq ? AddressNetwork.liquid : AddressNetwork.bitcoin,
        ),
      );
    }

    // Process address only if it has value.
    if (state.address.isNotEmpty) {
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
        case AddressNetwork.bip21Lightning:
          _processLnInvoice();
      }
    }
  }

  Future _processLnInvoice() async {
    final amt = state.invoice!.getAmount();

    WalletBloc? walletBlocc;
    var storedSwapTxIdx = -1;

    if (state.oneWallet) {
      walletBlocc = state.selectedWalletBloc;
      storedSwapTxIdx = walletBlocc!.state.wallet!.swaps.indexWhere(
        (element) =>
            element.lnSwapDetails != null &&
            element.lnSwapDetails!.invoice == state.invoice!.invoice,
      );
    } else {
      final mainWalletsBlocs = _homeCubit.state.walletBlocsFromNetwork(
        _networkCubit.state.getBBNetwork(),
      );

      // WalletBloc? walletBlocc;
      for (final walletBloc in mainWalletsBlocs) {
        final wallet = walletBloc.state.wallet!;
        storedSwapTxIdx = wallet.swaps.indexWhere(
          (element) =>
              element.lnSwapDetails != null &&
              element.lnSwapDetails!.invoice == state.invoice!.invoice,
        );

        if (storedSwapTxIdx != -1) {
          final swap = wallet.swaps[storedSwapTxIdx];
          final status = (swap.status != null) ? swap.status!.status : null;
          if (status != null && status != boltz.SwapStatus.invoiceSet) {
            emit(
              state.copyWith(
                errScanningAddress: 'Swap for this invoice already exists.',
                showSendButton: false,
              ),
            );
            return;
          }
          walletBlocc = walletBloc;
          break;
        }
      }
    }

    if (storedSwapTxIdx != -1 && walletBlocc != null) {
      emit(
        state.copyWith(
          selectedWalletBloc: walletBlocc,
          enabledWallets: [walletBlocc.state.wallet!.id],
        ),
      );

      final selectedWallet = walletBlocc.state.wallet!;
      final networkurl = selectedWallet.isLiquid()
          ? _networkCubit.state.getLiquidNetworkUrl()
          : _networkCubit.state.getNetworkUrl();

      if (amt == 0)
        emit(state.copyWith(showSendButton: false));
      else
        _checkBalance();
      // emit(state.copyWith(showSendButton: true));

      await _swapCubit.createSubSwapForSend(
        wallet: selectedWallet,
        address: state.address,
        invoice: state.invoice!,
        amount: amt,
        isTestnet: _networkCubit.state.testnet,
        networkUrl: networkurl,
      );
      return;
    }

    if (!state.oneWallet) {
      final wallets = _homeCubit.state.walletsWithEnoughBalance(
        amt,
        _networkCubit.state.getBBNetwork(),
        // onlyMain: true,
      );
      if (wallets.isEmpty) {
        emit(
          state.copyWith(
            errScanningAddress: 'No wallet with enough balance',
          ),
        );
        resetWalletSelection(clearInv: false);
        return;
      }

      final selectWalletBloc = state.selectLiqThenSecThenOtherBtc(wallets);
      emit(
        state.copyWith(
          selectedWalletBloc: selectWalletBloc,
          enabledWallets: wallets.map((_) => _.state.wallet!.id).toList(),
        ),
      );
    }

    if (amt == 0)
      emit(state.copyWith(showSendButton: false));
    else
      _checkBalance();

    // emit(state.copyWith(showSendButton: true));
  }

  Future _processBitcoinAddress() async {
    final amount = _currencyCubit.state.amount;

    if (!state.oneWallet) {
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
        final mainBitcoinWallet = _homeCubit.state
            .getMainSecureWallet(_networkCubit.state.getBBNetwork());
        emit(
          state.copyWith(
            selectedWalletBloc: mainBitcoinWallet,
          ),
        );
        return;
      }

      final couldBeOnChainSwap = state.couldBeOnchainSwap();
      final selectWallet = couldBeOnChainSwap == true
          ? state.selectedWalletBloc
          : state.selectMainBtcThenOtherHighestBalBtc(wallets);

      emit(
        state.copyWith(
          enabledWallets: wallets.map((_) => _.state.wallet!.id).toList(),
          selectedWalletBloc: selectWallet,
        ),
      );
    }

    if (amount == 0)
      emit(state.copyWith(showSendButton: false));
    else
      _checkBalance();

    // emit(state.copyWith(showSendButton: true));
  }

  Future _processLiquidAddress() async {
    final amount = _currencyCubit.state.amount;

    if (!state.oneWallet) {
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
    }

    if (amount == 0)
      emit(state.copyWith(showSendButton: false));
    else
      _checkBalance();
    // emit(state.copyWith(showSendButton: true));
  }

  void _checkBalance() {
    final balance = state.selectedWalletBloc?.state.balanceSats() ?? 0;
    final amount = _currencyCubit.state.amount;

    if (balance < amount) {
      emit(
        state.copyWith(
          errScanningAddress: 'Not enough balance',
          showSendButton: false,
        ),
      );
      return;
    }

    emit(state.copyWith(showSendButton: true, errScanningAddress: ''));
  }

  void resetWalletSelection({bool clearInv = true, bool changeWallet = true}) {
    if (state.oneWallet) {
      if (clearInv) emit(state.copyWith(invoice: null));
      return;
    }
    emit(
      state.copyWith(
        enabledWallets: [],
        selectedWalletBloc:
            changeWallet == true ? null : state.selectedWalletBloc,
        showSendButton: false,
        invoice: clearInv ? null : state.invoice,
        tempAmt: 0,
        signed: false,
        paymentNetwork: null,
      ),
    );
  }

  void resetErrors() => emit(
        state.copyWith(
          errScanningAddress: '',
          errSending: '',
          errDownloadingFile: '',
        ),
      );

  void updateWalletBloc(WalletBloc walletBloc) {
    emit(state.copyWith(selectedWalletBloc: walletBloc));
    sendAllCoin(false);
    _checkBalance();
  }

  void disabledDropdownClicked() {
    if (state.oneWallet) return;
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
    final amount = sendAll
        ? balance
        : state.isLnInvoice()
            ? state.invoice!.getAmount()
            : _currencyCubit.state.amount;
    _currencyCubit.updateAmountDirect(amount);
    _currencyCubit.updateAmount(amount == 0 ? '' : amount.toString());

    _checkBalance();
  }

  void utxoSelected(UTXO utxo) {
    var selectedUtxos = state.selectedUtxos.toList();

    if (selectedUtxos.containsUtxo(utxo))
      selectedUtxos = selectedUtxos.removeUtxo(utxo);
    else
      selectedUtxos.add(utxo);

    emit(state.copyWith(selectedUtxos: selectedUtxos));
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

  void buildOnchainTxFromSwap({
    required int networkFees,
    required SwapTx swaptx,
  }) async {
    if (state.sending) return;
    if (state.selectedWalletBloc == null) return;
    final w = state.selectedWalletBloc!.state.wallet;

    emit(state.copyWith(buildingOnChain: true));

    final localWalletBloc = _homeCubit.state.getWalletBlocById(w!.id);
    if (localWalletBloc == null) return;
    final localWallet = localWalletBloc.state.wallet;
    final isLiq = localWallet!.isLiquid();

    // if (!localWallet.mainWallet) return;

    final address = swaptx.scriptAddress;
    // final fee = networkFees;
    final fee =
        isLiq ? _networkCubit.state.pickLiquidFees() : networkFees.toDouble();

    // emit(state.copyWith(sending: true, errSending: ''));

    final isBitcoinSweep = localWallet.isBitcoin() &&
        state.onChainAbsFee != null &&
        state.onChainAbsFee != 0;
    final (buildResp, err) = await _walletTx.buildTx(
      wallet: localWallet,
      isManualSend: false,
      address: address,
      amount: swaptx.outAmount,
      // amount: 5000, // to test submarine refund
      sendAllCoin: false,
      feeRate: isBitcoinSweep ? 0 : fee,
      absFee: isBitcoinSweep ? state.onChainAbsFee : 0,
      enableRbf: true,
      note: state.note,
    );
    if (err != null) {
      emit(
        state.copyWith(
          errSending: err.toString(),
          sending: false,
          buildingOnChain: false,
        ),
      );
      return;
    }

    final (_, tx, feeAmt) = buildResp!;

    final updatedSwapTx = swaptx.copyWith(lockupFees: feeAmt);

    if (updatedSwapTx.totalFees()! + feeAmt! > updatedSwapTx.outAmount) {
      emit(
        state.copyWith(
          errSending: 'Fees is greater than output amount!',
          buildingOnChain: false,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        psbtSigned: tx!.psbt,
        psbtSignedFeeAmount: feeAmt,
        tx: tx.copyWith(swapTx: updatedSwapTx, isSwap: true),
        signed: true,
        sending: false,
        enabledWallets: [localWallet.id],
        buildingOnChain: false,
      ),
    );
  }

  void buildTxFromSwap({
    required int networkFees,
    required SwapTx swaptx,
  }) async {
    if (state.sending) return;
    if (state.selectedWalletBloc == null) return;
    final w = state.selectedWalletBloc!.state.wallet;

    final localWalletBloc = _homeCubit.state.getWalletBlocById(w!.id);
    if (localWalletBloc == null) return;
    final localWallet = localWalletBloc.state.wallet;
    final isLiq = localWallet!.isLiquid();

    // if (!localWallet.mainWallet) return;

    final address = swaptx.scriptAddress;
    // final fee = networkFees;
    final fee =
        isLiq ? _networkCubit.state.pickLiquidFees() : networkFees.toDouble();

    // emit(state.copyWith(sending: true, errSending: ''));

    final (buildResp, err) = await _walletTx.buildTx(
      wallet: localWallet,
      isManualSend: false,
      address: address,
      amount: swaptx.outAmount,
      // amount: 2500, // to test submarine refund
      sendAllCoin: false, //swaptx.isChainSwap() ? state.sendAllCoin : false,
      feeRate: swaptx.isChainSwap() &&
              state.onChainAbsFee != null &&
              state.onChainAbsFee! > 0
          ? 0
          : fee,
      enableRbf: true,
      note: state.note,
      absFee: swaptx.isChainSwap() ? state.onChainAbsFee : null,
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

    final (_, tx, feeAmt) = buildResp!;

    final updatedSwapTx = swaptx.copyWith(lockupFees: feeAmt);

    if (updatedSwapTx.totalFees()! + feeAmt! > updatedSwapTx.outAmount) {
      emit(
        state.copyWith(errSending: 'Fees is greater than output amount!'),
      );
      return;
    }

    // To auto broadcast the swap in case of LBTC -> LN Swap;
    if (state.couldBeOnchainSwap() == false &&
        state.isLnInvoice() == true &&
        tx?.isLiquid == true) {
      emit(
        state.copyWith(
          psbtSigned: tx!.psbt,
          psbtSignedFeeAmount: feeAmt,
          tx: tx.copyWith(swapTx: updatedSwapTx, isSwap: true),
          signed: true,
          sending: true,
          enabledWallets: [localWallet.id],
        ),
      );

      sendSwap();
    } else {
      emit(
        state.copyWith(
          psbtSigned: tx!.psbt,
          psbtSignedFeeAmount: feeAmt,
          tx: tx.copyWith(swapTx: updatedSwapTx, isSwap: true),
          signed: true,
          sending: false,
          enabledWallets: [localWallet.id],
        ),
      );
    }
  }

  // -----------------
  void sendSwap() async {
    emit(state.copyWith(sending: true, errSending: ''));

    final tx = state.tx!;
    final swap = state.tx!.swapTx!;
    final w = state.selectedWalletBloc!.state.wallet;

    final localWalletBloc = _homeCubit.state.getWalletBlocById(w!.id);
    if (localWalletBloc == null) return;
    final wallet = localWalletBloc.state.wallet;

    // if (!wallet!.isMain()) {
    //   emit(state.copyWith(errSending: "Submarine swaps currently only supported via "));
    //   return;
    // };
    final broadcastViaBoltz = _networkCubit.state.selectedLiquidNetwork !=
        LiquidElectrumTypes.bullbitcoin;
    final (wtxid, errBroadcast) = await _walletTx.broadcastTxWithWallet(
      wallet: wallet!,
      address: swap.scriptAddress,
      note: state.note,
      transaction: tx.copyWith(
        swapTx: swap,
        isSwap: true,
        // isLiquid: wallet.isLiquid(),
      ),
      useOnlyLwk: true, // !broadcastViaBoltz,
    );
    if (errBroadcast != null) {
      emit(state.copyWith(errSending: errBroadcast.toString(), sending: false));
      return;
    }

    final txWithId = tx.copyWith(txid: wtxid?.$2 ?? '');
    emit(state.copyWith(tx: txWithId));

    final (updatedWallet, _) = wtxid!;

    state.selectedWalletBloc!.add(
      UpdateWallet(
        updatedWallet,
        syncAfter: true,
        updateTypes: [
          UpdateWalletTypes.addresses,
          UpdateWalletTypes.transactions,
          UpdateWalletTypes.swaps,
        ],
      ),
    );
    // }
    Future.delayed(50.ms);
    // state.selectedWalletBloc!.add(SyncWallet());

    emit(state.copyWith(sending: false, sent: true));
  }

  void baseLayerBuild({required int networkFees}) async {
    if (state.sending) return;
    if (state.selectedWalletBloc == null) return;

    final localWallet = state.selectedWalletBloc!.state.wallet;
    final isLiq = localWallet!.isLiquid();

    final address = state.address;
    final fee =
        isLiq ? _networkCubit.state.pickLiquidFees() : networkFees.toDouble();

    final bool enableRbf;
    enableRbf = !state.disableRBF;

    emit(state.copyWith(sending: true, errSending: '', signed: false));

    final (buildResp, err) = await _walletTx.buildTx(
      wallet: localWallet,
      isManualSend: state.selectedUtxos.isNotEmpty,
      address: address,
      amount: _currencyCubit.state.amount,
      sendAllCoin: state.sendAllCoin,
      feeRate: fee,
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

    if (!wallet!.watchOnly()) {
      emit(
        state.copyWith(
          sending: false,
          psbtSigned: tx!.psbt,
          psbtSignedFeeAmount: feeAmt,
          tx: tx,
          signed: true,
        ),
      );

      final amountDirect = (tx.sent ?? 0) - (tx.received ?? 0);
      print('amountDirect: $amountDirect');
      // _currencyCubit.updateAmountDirect(amountDirect);
    } else {
      state.selectedWalletBloc!.add(
        UpdateWallet(
          wallet,
          updateTypes: [
            UpdateWalletTypes.transactions,
            UpdateWalletTypes.swaps,
          ],
        ),
      );

      emit(
        state.copyWith(
          sending: false,
          psbt: tx!.psbt!,
          tx: tx,
        ),
      );
    }
  }

  void baseLayerSend() async {
    if (state.selectedWalletBloc == null) return;
    emit(state.copyWith(sending: true, errSending: ''));
    final address = state.address;
    final (wtxid, err) = await _walletTx.broadcastTxWithWallet(
      wallet: state.selectedWalletBloc!.state.wallet!,
      address: address,
      note: state.note,
      transaction: state.tx!,
      // .copyWith(
      //   swapTx: swaptx,
      //   isSwap: swaptx != null,
      // ),
    );
    if (err != null) {
      emit(state.copyWith(errSending: err.toString(), sending: false));
      return;
    }

    final txWithId = state.tx?.copyWith(txid: wtxid?.$2 ?? '');
    emit(state.copyWith(tx: txWithId));

    final (wallet, _) = wtxid!;

    // if (swaptx != null) {
    //   final (updatedWalletWithTxid, err2) = await _walletTx.addSwapTxToWallet(
    //     wallet: wallet,
    //     swapTx: swaptx.copyWith(txid: txid),
    //   );

    //   if (err2 != null) {
    //     emit(state.copyWith(errSending: err.toString()));
    //     return;
    //   }

    //   state.selectedWalletBloc!.add(
    //     UpdateWallet(
    //       updatedWalletWithTxid,
    //       updateTypes: [
    //         UpdateWalletTypes.addresses,
    //         UpdateWalletTypes.transactions,
    //         UpdateWalletTypes.swaps,
    //       ],
    //     ),
    //   );
    // } else {
    state.selectedWalletBloc!.add(
      UpdateWallet(
        wallet,
        updateTypes: [
          UpdateWalletTypes.addresses,
          UpdateWalletTypes.transactions,
          UpdateWalletTypes.swaps,
        ],
      ),
    );
    // }
    Future.delayed(150.ms);
    state.selectedWalletBloc!.add(SyncWallet());

    emit(state.copyWith(sending: false, sent: true));
  }

  void updateOnChainAbsFee(int fee) {
    emit(
      state.copyWith(
        onChainAbsFee: fee,
        onChainSweep: true,
      ),
    );
  }

  void reset() async {
    emit(
      state.copyWith(
        tx: null,
        signed: false,
        psbtSigned: null,
        psbtSignedFeeAmount: 0,
        onChainAbsFee: 0,
        onChainSweep: false,
        enabledWallets: [],
      ),
    );
  }

  // void txSettled() {
  //   if (state.tx == null) return;
  //   emit(state.copyWith(txSettled: true));
  // }

  // void txPaid() {
  //   if (state.tx == null) return;
  //   emit(state.copyWith(txPaid: true));
  // }

  Future<int> calculateFeeForSend({
    Wallet? wallet,
    String address = '',
    required int networkFees,
  }) async {
    final isLiq = wallet!.isLiquid();

    final fee =
        isLiq ? _networkCubit.state.pickLiquidFees() : networkFees.toDouble();

    // final amount =
    //     wallet.balance! - 900 > 1000 ? wallet.balance! - 900 : wallet.balance!;

    final (buildResp, err) = await _walletTx.buildTx(
      wallet: wallet,
      isManualSend: false,
      address: address,
      amount: wallet.balance,
      sendAllCoin: true,
      feeRate: fee,
      enableRbf: true,
    );
    if (err != null) {
      emit(
        state.copyWith(
          errSending: err.toString(),
          sending: false,
        ),
      );
      return 0;
    }

    final (walletResp, tx, feeAmt) = buildResp!;

    return feeAmt ?? 0;
  }

  void processSendButton(String label) async {
    final network =
        _networkCubit.state.testnet ? BBNetwork.Testnet : BBNetwork.Mainnet;
    final (_, addressError) =
        await state.getPaymentNetwork(state.address, network);

    if (addressError != null) {
      emit(state.copyWith(errAddresses: 'Invalid address'));
      return;
    }

    final isOnchainSwap = state.couldBeOnchainSwap();
    final wallet = state.selectedWalletBloc!.state.wallet!;

    if (isOnchainSwap) {
      int sweepAmount = 0;
      final refundAddress = wallet.lastGeneratedAddress?.address;
      if (state.sendAllCoin == true) {
        final feeRate = _networkFeesCubit.state.selectedOrFirst(true);
        final fees = await calculateFeeForSend(
          wallet: wallet,
          address: refundAddress!,
          networkFees: feeRate,
        );

        reset();

        if (wallet.isBitcoin()) {
          // TODO: Absolute fee doesn't work for liquid build Tx now
          updateOnChainAbsFee(fees);
        }

        // sweepAmount = walletBloc.state.wallet!.balance! - fees;
        final int magicNumber = wallet.isBitcoin()
            ? 0 // 30 // Rather abs fee is taken from above dummy drain tx
            : 1500;
        sweepAmount = wallet.balance! - fees - magicNumber; // TODO
      }

      final swapAmount = _currencyCubit.state.amount;

      final liqNetworkurl = _networkCubit.state.getLiquidNetworkUrl();
      final btcNetworkUrl = _networkCubit.state.getNetworkUrl();
      final btcNetworkUrlWithoutSSL = btcNetworkUrl.startsWith('ssl://')
          ? btcNetworkUrl.split('//')[1]
          : btcNetworkUrl;

      _swapCubit.createOnChainSwap(
        wallet: wallet,
        amount: state.sendAllCoin == true ? sweepAmount : swapAmount,
        isTestnet: _networkCubit.state.testnet,
        btcElectrumUrl:
            btcNetworkUrlWithoutSSL, // 'electrum.blockstream.info:60002',
        lbtcElectrumUrl: liqNetworkurl, // 'blockstream.info:465',
        toAddress: state.address, // recipientAddress.address;
        refundAddress: refundAddress!,
        direction: wallet.isBitcoin()
            ? boltz.ChainSwapDirection.btcToLbtc
            : boltz.ChainSwapDirection.lbtcToBtc,
        toWalletId: '',
        onChainSwapType: OnChainSwapType.sendSwap,
      );

      return;
    }

    final isLn = state.isLnInvoice();

    if (!state.signed) {
      if (!isLn) {
        final fees = _networkFeesCubit.state.selectedOrFirst(false);
        baseLayerBuild(networkFees: fees);
        return;
      }
      // context.read<WalletBloc>().state.wallet;
      final isLiq = wallet.isLiquid();
      final networkurl = !isLiq
          ? _networkCubit.state.getNetworkUrl()
          : _networkCubit.state.getLiquidNetworkUrl();

      _swapCubit.createSubSwapForSend(
        wallet: wallet,
        address: state.address,
        amount: _currencyCubit.state.amount,
        isTestnet: _networkCubit.state.testnet,
        invoice: state.invoice!,
        networkUrl: networkurl,
        label: label,
      );
      return;
    }

    if (!isLn) {
      baseLayerSend();
      return;
    }
    sendSwap();
  }

  void buildChainSwap(
    Wallet fromWallet,
    Wallet toWallet,
    int amount,
    bool sweep,
  ) async {
    if (amount == 0 && sweep == false) {
      _swapCubit.setValidationError(
        'Please enter valid amount',
      );
      return;
    }

    if (amount > fromWallet.balance!) {
      _swapCubit.setValidationError(
        'Not enough balance.\nWallet balance is: ${fromWallet.balance!} sats.',
      );
      return;
    }

    final walletBloc = _homeCubit.state.getWalletBlocById(fromWallet.id);
    updateWalletBloc(walletBloc!);

    final recipientAddress = toWallet.lastGeneratedAddress?.address ?? '';
    final refundAddress = fromWallet.lastGeneratedAddress?.address ?? '';

    final liqNetworkurl = _networkCubit.state.getLiquidNetworkUrl();
    final btcNetworkUrl = _networkCubit.state.getNetworkUrl();
    final btcNetworkUrlWithoutSSL = btcNetworkUrl.startsWith('ssl://')
        ? btcNetworkUrl.split('//')[1]
        : btcNetworkUrl;

    await Future.delayed(Duration.zero);

    int finalAmount = amount;
    bool finalSweep = sweep;
    if (sweep == true) {
      // } else {
      final feeRate = _networkFeesCubit.state.selectedOrFirst(true);

      final fees = await calculateFeeForSend(
        wallet: walletBloc.state.wallet,
        address: refundAddress,
        networkFees: feeRate,
      );

      reset();
      final wallet = walletBloc.state.wallet;
      if (wallet == null) return;
      if (wallet.isBitcoin()) {
        // TODO: Absolute fee doesn't work for liquid build Tx now
        updateOnChainAbsFee(fees);
      }

      // sweepAmount = walletBloc.state.wallet!.balance! - fees;
      final frozenUtxos = fromWallet.allFreezedUtxos().isNotEmpty;
      int finalBalance = walletBloc.state.wallet!.balance!;
      if (frozenUtxos == true) {
        finalBalance = fromWallet.utxos
            .where((UTXO utxo) => utxo.spendable)
            .map((UTXO utxo) => utxo.value)
            .reduce((v, elm) => v + elm);
        finalSweep = false;
      }

      final int magicNumber = wallet.isBitcoin()
          ? 0 // 30 // Rather abs fee is taken from above dummy drain tx
          : 1500;
      finalAmount = finalBalance - fees - magicNumber; // TODO:
      // }
      // -20 works for btc
      // -1500 works for l-btc
    }

    _swapCubit.createOnChainSwap(
      wallet: fromWallet,
      amount: finalAmount, //20000,
      sweep: finalSweep,
      isTestnet: _networkCubit.state.testnet,
      btcElectrumUrl:
          btcNetworkUrlWithoutSSL, // 'electrum.blockstream.info:60002',
      lbtcElectrumUrl: liqNetworkurl, // 'blockstream.info:465',
      toAddress: recipientAddress, // recipientAddress.address;
      refundAddress: refundAddress,
      direction: fromWallet.isBitcoin()
          ? boltz.ChainSwapDirection.btcToLbtc
          : boltz.ChainSwapDirection.lbtcToBtc,
      toWalletId: toWallet.id,
      onChainSwapType: OnChainSwapType.selfSwap,
    );
  }

  void dispose() {
    super.close();
  }
}

// bolt 11 testnet
//lntb11110n1pnrc620pp5mpdwk98cl7wnj9mwc69wf7v8t7fadt2n4rx22g8rzf2y48l8m4esdpz2djkuepqw3hjqnpdgf2yxgrpv3j8yetnwvcqz95xqyp2xqsp5vwyhphcdvhc399ffqqsphp4xzjg569rchzkh9kte048hajxu2hns9qyyssqqy24765myh9ew4zklqx8qhycg9g4rn7w56t75vhfqk9a2sjpedsp4t90ms20ufckmc0fgjrhvfxcrdmhv5780wmezl7ps2djcuqtnhsp07jm9w


// BIP21 URI with On-chain address
// bitcoin:BC1QYLH3U67J673H6Y6ALV70M0PL2YZ53TZHVXGG7U?amount=0.00001&label=sbddesign%3A%20For%20lunch%20Tuesday&message=For%20lunch%20Tuesday

// BIP21 URI with BOLT 11 invoice
// bitcoin:BC1QYLH3U67J673H6Y6ALV70M0PL2YZ53TZHVXGG7U?amount=0.00001&label=sbddesign%3A%20For%20lunch%20Tuesday&message=For%20lunch%20Tuesday&lightning=LNBC10U1P3PJ257PP5YZTKWJCZ5FTL5LAXKAV23ZMZEKAW37ZK6KMV80PK4XAEV5QHTZ7QDPDWD3XGER9WD5KWM36YPRX7U3QD36KUCMGYP282ETNV3SHJCQZPGXQYZ5VQSP5USYC4LK9CHSFP53KVCNVQ456GANH60D89REYKDNGSMTJ6YW3NHVQ9QYYSSQJCEWM5CJWZ4A6RFJX77C490YCED6PEMK0UPKXHY89CMM7SCT66K8GNEANWYKZGDRWRFJE69H9U5U0W57RRCSYSAS7GADWMZXC8C6T0SPJAZUP6

// BIP21 URI with BOLT 12 offer
// bitcoin:BC1QYLH3U67J673H6Y6ALV70M0PL2YZ53TZHVXGG7U?amount=0.00021&label=sbddesign%3A%20For%20lunch%20Tuesday&message=For%20lunch%20Tuesday&lightning=LNO1PG257ENXV4EZQCNEYPE82UM50YNHXGRWDAJX283QFWDPL28QQMC78YMLVHMXCSYWDK5WRJNJ36JRYG488QWLRNZYJCZS

// BOLT 11 Invoice mainnet
// LNBC10U1P3PJ257PP5YZTKWJCZ5FTL5LAXKAV23ZMZEKAW37ZK6KMV80PK4XAEV5QHTZ7QDPDWD3XGER9WD5KWM36YPRX7U3QD36KUCMGYP282ETNV3SHJCQZPGXQYZ5VQSP5USYC4LK9CHSFP53KVCNVQ456GANH60D89REYKDNGSMTJ6YW3NHVQ9QYYSSQJCEWM5CJWZ4A6RFJX77C490YCED6PEMK0UPKXHY89CMM7SCT66K8GNEANWYKZGDRWRFJE69H9U5U0W57RRCSYSAS7GADWMZXC8C6T0SPJAZUP6


// 6000 sats
// lnbc60u1pnre9sysp5luy79ufxhywcnage3eswwra6tuk62x4x9p9djgyd5x2jy54gmpmspp5chhrwxtceu20k9nhlsy8zhzwsxht79lvfatu20eegjzmxljrlz8sdpz2djkuepqw3hjqnpdgf2yxgrpv3j8yetnwvxqyp2xqcqz959qxpqysgq8zseyvltvj5ny698mkg20pzccuqk9dpt5stues0jcc4hhdxe8ehrm3x7md52w493udwvz3yastu9ht4zvuykupmdaclf7323djl0mdsp2h2rmx

// 1234 sats
// lnbc12340n1pnretv7sp5d87xcykdvf03adm2au86ssury8fggz3jra5af3pmya0ftn32pjhqpp5ekmafv4q72f25d0varnp5h0cmqpqkjv20t9klcj9vaevp7dxd5cqdpz2djkuepqw3hjqnpdgf2yxgrpv3j8yetnwvxqyp2xqcqz959qxpqysgq2357qtv82qgpdttzn82hsnyha3tfgvgldc0fc8nrf7qxaxq0yt79fsehc3wprjld7hqwdeau4ct6fl6gxq99gvaulqthhludgqzmxrgpk4zw6n

// 1234 testnet 
// lntb12340n1pnrevr8pp57e8n6mqr8zwajjpe4r7nxsy0v4aql2h3edfdyjerda4neghj564qdpz2djkuepqw3hjqnpdgf2yxgrpv3j8yetnwvcqz95xqyp2xqsp52m4ue6g3r56xfeac69e95ewvhnrna8upv25kd97890v8czdyvfnq9qyyssq4g2efr6ck9d8ylyzuv5ahudxfr4zh30p3c5g00xmmkpqex2c08vjlhtjqr7h5lpc04v0e84hav52um4ak2q94zuncxm0vs222pu733gpa6y7fa
