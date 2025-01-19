import 'dart:async';

import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/swap.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/boltz/swap.dart';
import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/payjoin/event.dart';
import 'package:bb_mobile/_pkg/payjoin/manager.dart';
import 'package:bb_mobile/_pkg/wallet/bip21.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/_repositories/app_wallets_repository.dart';
import 'package:bb_mobile/_repositories/network_repository.dart';
import 'package:bb_mobile/_repositories/wallet_service.dart';
import 'package:bb_mobile/send/bloc/send_state.dart';
import 'package:bb_mobile/swap/create_swap_bloc/swap_cubit.dart';
import 'package:boltz/boltz.dart' as boltz;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SendCubit extends Cubit<SendState> {
  SendCubit({
    required Barcode barcode,
    required WalletTx walletTx,
    required FileStorage fileStorage,
    required NetworkRepository networkRepository,
    required AppWalletsRepository appWalletsRepository,
    required bool openScanner,
    required bool defaultRBF,
    required PayjoinManager payjoinManager,
    required SwapBoltz swapBoltz,
    required CreateSwapCubit swapCubit,
    Wallet? wallet,
    bool oneWallet = true,
  })  : _appWalletsRepository = appWalletsRepository,
        _networkRepository = networkRepository,
        _walletTx = walletTx,
        _fileStorage = fileStorage,
        _barcode = barcode,
        _payjoinManager = payjoinManager,
        _swapBoltz = swapBoltz,
        _swapCubit = swapCubit,
        super(
          SendState(
            oneWallet: oneWallet,
            selectedWallet: wallet,
          ),
        ) {
    emit(
      state.copyWith(
        disableRBF: !defaultRBF,
      ),
    );

    if (openScanner) scanAddress();
    if (wallet != null) selectWallets(fromStart: true);

    _pjEventSubscription = PayjoinEventBus().stream.listen((event) {
      if (event is PayjoinSenderPostMessageASuccessEvent) {
        if (event.pjUri != state.payjoinEndpoint.toString()) return;
        emit(
          state.copyWith(
            isPayjoinPostSuccess: true,
          ),
        );
      } else if (event is PayjoinBroadcastEvent) {
        _appWalletsRepository
            .getWalletServiceById(state.selectedWallet!.id)
            ?.syncWallet();
      } else if (event is PayjoinSendFailureEvent &&
          event.pjUri == state.payjoinEndpoint.toString()) {
        emit(
          state.copyWith(
            errSending: event.error.toString(),
            sending: false,
          ),
        );
      }
    });
  }

  late StreamSubscription<PayjoinEvent> _pjEventSubscription;
  final Barcode _barcode;
  final FileStorage _fileStorage;
  final WalletTx _walletTx;
  final PayjoinManager _payjoinManager;
  final SwapBoltz _swapBoltz;

  final CreateSwapCubit _swapCubit;
  final NetworkRepository _networkRepository;
  final AppWalletsRepository _appWalletsRepository;

  @override
  Future<void> close() {
    _pjEventSubscription.cancel();
    return super.close();
  }

  Future<void> updateAddress(
    String? addr, {
    bool changeWallet = true,
    int? currentAmt,
  }) async {
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
    final network = _networkRepository.getBBNetwork;
    final (paymentNetwork, err) =
        await state.getPaymentNetwork(address, network);
    if (err != null) {
      emit(
        state.copyWith(
          errScanningAddress: err.toString(),
          scanningAddress: false,
          invoice: null,
          note: '',
        ),
      );

      emit(state.copyWith(tempAmt: 0, tempStrAmt: ''));

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

    emit(
      state.copyWith(
        paymentNetwork: paymentNetwork,
        payjoinEndpoint: null,
        payjoinSender: null,
      ),
    );

    switch (paymentNetwork) {
      case AddressNetwork.bip21Bitcoin:
        final bip21Obj = bip21.decode(address);
        final newAddress = bip21Obj.address;
        emit(state.copyWith(address: newAddress));
        final amount = bip21Obj.options['amount'] as num?;
        if (amount != null) {
          final amountInSats = (amount * 100000000).toInt();

          emit(
            state.copyWith(
              btcTempAmt: amount.toDouble(),
              tempAmt: amountInSats,
            ),
          );
        }
        final label = bip21Obj.options['label'] as String?;
        if (label != null) {
          emit(state.copyWith(note: label));
        }
        final pjParam = bip21Obj.options['pj'] as String?;
        if (pjParam != null) {
          final parsedPjParam = Uri.parse(pjParam);
          final partialEncodedPjParam =
              parsedPjParam.toString().replaceAll('#', '%23');
          final encodedPjParam = partialEncodedPjParam.replaceAll('%20', '+');
          emit(state.copyWith(payjoinEndpoint: Uri.parse(encodedPjParam)));
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
          final amountInSats = state.convertBtcStringToSats(amount.toString());

          emit(
            state.copyWith(
              tempAmt: amountInSats,
              btcTempAmt: amount.toDouble(),
            ),
          );
        }
        final label = bip21Obj.options['label'] as String?;
        if (label != null) {
          emit(state.copyWith(note: label));
        }
      case AddressNetwork.lightning:
        final boltzUrl =
            _networkRepository.testnet ? boltzTestnetUrl : boltzMainnetUrl;
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
        if (_networkRepository.testnet != inv.isTestnet()) {
          emit(state.copyWith(errScanningAddress: 'Network mismatch'));
          return;
        }

        emit(
          state.copyWith(
            invoice: inv,
            address: address,
            tempAmt: inv.getAmount(),
          ),
        );

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
        if (_networkRepository.testnet != inv.isTestnet()) {
          emit(state.copyWith(errScanningAddress: 'Network mismatch'));

          return;
        }

        emit(
          state.copyWith(
            invoice: inv,
            address: invoice,
            tempAmt: inv.getAmount(),
          ),
        );

      case AddressNetwork.bitcoin:
        emit(state.copyWith(address: address));

      case AddressNetwork.liquid:
        emit(state.copyWith(address: address));
    }

    emit(state.copyWith(scanningAddress: false));
    if (changeWallet == true) {
      selectWallets();
    }
  }

  void selectWallets({bool fromStart = false}) {
    resetErrors();
    if (!fromStart) {
      if (state.paymentNetwork == null) return;
    } else {
      final isLiq = state.selectedWallet!.isLiquid();
      emit(
        state.copyWith(
          paymentNetwork:
              isLiq ? AddressNetwork.liquid : AddressNetwork.bitcoin,
        ),
      );
    }

    final amt = fromStart ? 0 : state.tempAmt ?? 0;

    if (state.address.isNotEmpty) {
      switch (state.paymentNetwork!) {
        case AddressNetwork.bip21Bitcoin:
          _processBitcoinAddress(amt);
        case AddressNetwork.bip21Liquid:
          _processLiquidAddress(amt);
        case AddressNetwork.lightning:
          _processLnInvoice();
        case AddressNetwork.bitcoin:
          _processBitcoinAddress(amt);
        case AddressNetwork.liquid:
          _processLiquidAddress(amt);
        case AddressNetwork.bip21Lightning:
          _processLnInvoice();
      }
    }
  }

  Future _processLnInvoice() async {
    final amt = state.invoice!.getAmount();

    Wallet? wallett;
    var storedSwapTxIdx = -1;

    if (state.oneWallet) {
      wallett = state.selectedWallet;
      storedSwapTxIdx = wallett!.swaps.indexWhere(
        (element) =>
            element.lnSwapDetails != null &&
            element.lnSwapDetails!.invoice == state.invoice!.invoice,
      );
    } else {
      final mainWallets = _appWalletsRepository
          .walletsFromNetwork(_networkRepository.getBBNetwork);

      for (final wallet in mainWallets) {
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
          wallett = wallet;
          break;
        }
      }
    }

    if (storedSwapTxIdx != -1 && wallett != null) {
      emit(
        state.copyWith(
          selectedWallet: wallett,
          enabledWallets: [wallett.id],
        ),
      );

      final selectedWallet = wallett;
      final networkurl = selectedWallet.isLiquid()
          ? _networkRepository.getLiquidNetworkUrl
          : _networkRepository.getNetworkUrl;

      if (amt == 0) {
        emit(state.copyWith(showSendButton: false));
      } else {
        checkBalance(amt);
      }

      await _swapCubit.createSubSwapForSend(
        wallet: selectedWallet,
        address: state.address,
        invoice: state.invoice!,
        amount: amt,
        isTestnet: _networkRepository.testnet,
        networkUrl: networkurl,
      );
      return;
    }

    if (!state.oneWallet) {
      final wallets = _appWalletsRepository.walletsWithEnoughBalance(
        amt,
        _networkRepository.getBBNetwork,
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

      final selectWallet = state.selectLiqThenSecThenOtherBtc2(wallets);
      emit(
        state.copyWith(
          selectedWallet: selectWallet,
          enabledWallets: wallets.map((_) => _.id).toList(),
        ),
      );
    }

    if (amt == 0) {
      emit(state.copyWith(showSendButton: false));
    } else {
      checkBalance(amt);
    }
  }

  Future _processBitcoinAddress(int amount) async {
    if (!state.oneWallet) {
      final wallets = _appWalletsRepository.walletsWithEnoughBalance(
        amount,
        _networkRepository.getBBNetwork,
        onlyBitcoin: true,
      );
      if (wallets.isEmpty) {
        emit(
          state.copyWith(
            errScanningAddress: 'No wallet with enough balance',
          ),
        );
        resetWalletSelection();
        final mainBitcoinWallet = _appWalletsRepository
            .getMainSecureWallet(_networkRepository.getBBNetwork);
        emit(
          state.copyWith(
            selectedWallet: mainBitcoinWallet,
          ),
        );
        return;
      }

      final couldBeOnChainSwap = state.couldBeOnchainSwap();
      final selectWallet = couldBeOnChainSwap == true
          ? state.selectedWallet
          : state.selectMainBtcThenOtherHighestBalBtc2(wallets);

      emit(
        state.copyWith(
          enabledWallets: wallets.map((_) => _.id).toList(),
          selectedWallet: selectWallet,
        ),
      );
    }

    if (amount == 0) {
      emit(state.copyWith(showSendButton: false));
    } else {
      checkBalance(amount);
    }
  }

  Future _processLiquidAddress(int amount) async {
    if (!state.oneWallet) {
      final wallets = _appWalletsRepository.walletsWithEnoughBalance(
        amount,
        _networkRepository.getBBNetwork,
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
          selectedWallet: wallets.first,
          enabledWallets: wallets.map((_) => _.id).toList(),
        ),
      );
    }

    if (amount == 0) {
      emit(state.copyWith(showSendButton: false));
    } else {
      checkBalance(amount);
    }
  }

  void checkBalance(int amount) {
    final balance = state.selectedWallet?.balanceSats() ?? 0;

    if (amount == 0) {
      emit(state.copyWith(showSendButton: false));
      return;
    }

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
        selectedWallet: changeWallet == true ? null : state.selectedWallet,
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

  void updateWallet(Wallet wallet, int amt, bool unitsInSats) {
    emit(state.copyWith(selectedWallet: wallet));
    sendAllCoin(false, amt, unitsInSats);
    checkBalance(amt);
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

  Future<void> scanAddress() async {
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

  void sendAllCoin(bool sendAll, int amount, bool unitsInSats) {
    if (state.selectedWallet == null) return;
    emit(
      state.copyWith(
        sendAllCoin: sendAll,
      ),
    );
    final balance = state.selectedWallet!.balanceSats();

    final directAmt = sendAll
        ? balance
        : state.isLnInvoice()
            ? state.invoice!.getAmount()
            : amount;

    emit(state.copyWith(tempAmt: directAmt));

    final bal = unitsInSats
        ? state.selectedWallet!.balanceSats().toString()
        : state.selectedWallet!.balanceStr();

    final da = directAmt == 0
        ? ''
        : !sendAll && state.isLnInvoice()
            ? directAmt.toString()
            : bal;

    emit(state.copyWith(tempStrAmt: da));

    checkBalance(amount);
  }

  void togglePayjoin(bool toggle) {
    emit(state.copyWith(togglePayjoin: toggle));
  }

  void utxoSelected(UTXO utxo) {
    var selectedUtxos = state.selectedUtxos.toList();

    if (selectedUtxos.containsUtxo(utxo)) {
      selectedUtxos = selectedUtxos.removeUtxo(utxo);
    } else {
      selectedUtxos.add(utxo);
    }

    emit(state.copyWith(selectedUtxos: selectedUtxos));
  }

  void clearSelectedUtxos() {
    emit(state.copyWith(selectedUtxos: []));
  }

  Future<void> downloadPSBTClicked() async {
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

  Future<void> buildOnchainTxFromSwap({
    required int networkFees,
    required SwapTx swaptx,
  }) async {
    if (state.sending) return;
    if (state.selectedWallet == null) return;
    final w = state.selectedWallet!;

    emit(state.copyWith(buildingOnChain: true));

    final localWallet = _appWalletsRepository.getWalletById(w.id);
    if (localWallet == null) return;

    final isLiq = localWallet.isLiquid();

    final address = swaptx.scriptAddress;

    final fee =
        isLiq ? _networkRepository.pickLiquidFees : networkFees.toDouble();

    final isBitcoinSweep = localWallet.isBitcoin() &&
        state.onChainAbsFee != null &&
        state.onChainAbsFee != 0;
    final (buildResp, err) = await _walletTx.buildTx(
      wallet: localWallet,
      isManualSend: false,
      address: address,
      amount: swaptx.outAmount,
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

  Future<void> buildTxFromSwap({
    required int networkFees,
    required SwapTx swaptx,
  }) async {
    if (state.sending) return;
    if (state.selectedWallet == null) return;
    final w = state.selectedWallet!;

    final localWallet = _appWalletsRepository.getWalletById(w.id);
    if (localWallet == null) return;

    final isLiq = localWallet.isLiquid();

    final address = swaptx.scriptAddress;

    final fee =
        isLiq ? _networkRepository.pickLiquidFees : networkFees.toDouble();

    final (buildResp, err) = await _walletTx.buildTx(
      wallet: localWallet,
      isManualSend: false,
      address: address,
      amount: swaptx.outAmount,
      sendAllCoin: false,
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

  Future<void> sendSwap() async {
    emit(state.copyWith(sending: true, errSending: ''));

    final tx = state.tx!;
    final swap = state.tx!.swapTx!;
    final w = state.selectedWallet!;

    final wallet = _appWalletsRepository.getWalletById(w.id);
    if (wallet == null) return;

    final (wtxid, errBroadcast) = await _walletTx.broadcastTxWithWallet(
      wallet: wallet,
      address: swap.scriptAddress,
      note: state.note,
      transaction: tx.copyWith(
        swapTx: swap,
        isSwap: true,
      ),
      useOnlyLwk: true,
    );
    if (errBroadcast != null) {
      emit(state.copyWith(errSending: errBroadcast.toString(), sending: false));
      return;
    }

    final txWithId = tx.copyWith(txid: wtxid?.$2 ?? '');
    emit(state.copyWith(tx: txWithId));

    final (updatedWallet, _) = wtxid!;

    await _appWalletsRepository.getWalletServiceById(wallet.id)?.updateWallet(
      updatedWallet,
      syncAfter: true,
      updateTypes: [
        UpdateWalletTypes.addresses,
        UpdateWalletTypes.transactions,
        UpdateWalletTypes.swaps,
      ],
    );

    Future.delayed(50.ms);

    emit(state.copyWith(sending: false, sent: true));
  }

  Future<void> baseLayerBuild({
    required int networkFees,
    required int amount,
  }) async {
    if (state.sending) return;
    if (state.selectedWallet == null) return;

    final localWallet = state.selectedWallet!;
    final isLiq = localWallet.isLiquid();

    final address = state.address;
    final fee =
        isLiq ? _networkRepository.pickLiquidFees : networkFees.toDouble();

    final bool enableRbf;
    enableRbf = !state.disableRBF;

    emit(state.copyWith(sending: true, errSending: '', signed: false));

    final (buildResp, err) = await _walletTx.buildTx(
      wallet: localWallet,
      isManualSend: state.selectedUtxos.isNotEmpty,
      address: address,
      amount: amount,
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
      debugPrint('amountDirect: $amountDirect');
    } else {
      await _appWalletsRepository.getWalletServiceById(wallet.id)?.updateWallet(
        wallet,
        updateTypes: [
          UpdateWalletTypes.addresses,
          UpdateWalletTypes.transactions,
          UpdateWalletTypes.swaps,
        ],
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

  Future<void> payjoinBuild({
    required int networkFees,
    required String originalPsbt,
    required Wallet wallet,
    required int amount,
  }) async {
    final pjUriString =
        'bitcoin:${state.address}?amount=${amount / 100000000}&label=${Uri.encodeComponent(state.note)}&pj=${state.payjoinEndpoint!}&pjos=0';
    final sender = await _payjoinManager.initSender(
      pjUriString,
      networkFees,
      originalPsbt,
    );
    emit(state.copyWith(payjoinSender: sender));
  }

  Future<void> payjoinSend(Wallet wallet) async {
    if (state.selectedWallet == null) return;
    if (state.payjoinSender == null) return;

    emit(state.copyWith(sending: true, sent: false));
    _payjoinManager.spawnNewSender(
      isTestnet: _networkRepository.testnet,
      sender: state.payjoinSender!,
      wallet: wallet,
      pjUrl: state.payjoinEndpoint!.toString(),
    );
  }

  Future<void> baseLayerSend() async {
    if (state.selectedWallet == null) return;
    emit(state.copyWith(sending: true, errSending: ''));
    final address = state.address;
    final (wtxid, err) = await _walletTx.broadcastTxWithWallet(
      wallet: state.selectedWallet!,
      address: address,
      note: state.note,
      transaction: state.tx!,
    );
    if (err != null) {
      emit(state.copyWith(errSending: err.toString(), sending: false));
      return;
    }

    final txWithId = state.tx?.copyWith(txid: wtxid?.$2 ?? '');
    emit(state.copyWith(tx: txWithId));

    final (wallet, _) = wtxid!;

    await _appWalletsRepository.getWalletServiceById(wallet.id)?.updateWallet(
      wallet,
      syncAfter: true,
      updateTypes: [
        UpdateWalletTypes.addresses,
        UpdateWalletTypes.transactions,
        UpdateWalletTypes.swaps,
      ],
    );

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

  Future<void> reset() async {
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

  Future<int> calculateFeeForSend({
    Wallet? wallet,
    String address = '',
    required int networkFees,
  }) async {
    final isLiq = wallet!.isLiquid();

    final fee =
        isLiq ? _networkRepository.pickLiquidFees : networkFees.toDouble();

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

  Future<void> processSendButton({
    required String label,
    required int feeRate,
    required int amt,
  }) async {
    final network = _networkRepository.getBBNetwork;
    final (_, addressError) =
        await state.getPaymentNetwork(state.address, network);

    if (addressError != null) {
      emit(state.copyWith(errAddresses: 'Invalid address'));
      return;
    }

    final isOnchainSwap = state.couldBeOnchainSwap();
    final wallet = state.selectedWallet!;

    if (isOnchainSwap) {
      int sweepAmount = 0;
      final refundAddress = wallet.lastGeneratedAddress?.address;
      if (state.sendAllCoin == true) {
        final fees = await calculateFeeForSend(
          wallet: wallet,
          address: refundAddress!,
          networkFees: feeRate,
        );

        reset();

        if (wallet.isBitcoin()) {
          updateOnChainAbsFee(fees);
        }

        final int magicNumber = wallet.isBitcoin() ? 0 : 1500;
        sweepAmount = wallet.balance! - fees - magicNumber;
      }

      final swapAmount = amt;

      final liqNetworkurl = _networkRepository.getLiquidNetworkUrl;
      final btcNetworkUrl = _networkRepository.getNetworkUrl;
      final btcNetworkUrlWithoutSSL = btcNetworkUrl.startsWith('ssl://')
          ? btcNetworkUrl.split('//')[1]
          : btcNetworkUrl;

      _swapCubit.createOnChainSwap(
        wallet: wallet,
        amount: state.sendAllCoin == true ? sweepAmount : swapAmount,
        isTestnet: _networkRepository.testnet,
        btcElectrumUrl: btcNetworkUrlWithoutSSL,
        lbtcElectrumUrl: liqNetworkurl,
        toAddress: state.address,
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
        await baseLayerBuild(networkFees: feeRate, amount: amt);
        if (state.hasPjParam()) {
          await payjoinBuild(
            networkFees: feeRate,
            originalPsbt: state.psbtSigned!,
            wallet: wallet,
            amount: amt,
          );
          return;
        }
        return;
      }

      final isLiq = wallet.isLiquid();
      final networkurl = !isLiq
          ? _networkRepository.getNetworkUrl
          : _networkRepository.getLiquidNetworkUrl;

      _swapCubit.createSubSwapForSend(
        wallet: wallet,
        address: state.address,
        amount: amt,
        isTestnet: _networkRepository.testnet,
        invoice: state.invoice!,
        networkUrl: networkurl,
        label: label,
      );
      return;
    }

    if (state.payjoinSender != null) {
      await payjoinSend(wallet);
      return;
    }
    if (!isLn) {
      baseLayerSend();
      return;
    }
    sendSwap();
  }

  Future<void> buildChainSwap({
    required Wallet fromWallet,
    required Wallet toWallet,
    required int amount,
    required bool sweep,
    required int feeRate,
    required bool unitsInSats,
  }) async {
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

    final wallett = _appWalletsRepository.getWalletById(fromWallet.id);
    updateWallet(wallett!, amount, unitsInSats);

    final recipientAddress = toWallet.lastGeneratedAddress?.address ?? '';
    final refundAddress = fromWallet.lastGeneratedAddress?.address ?? '';

    final liqNetworkurl = _networkRepository.getLiquidNetworkUrl;
    final btcNetworkUrl = _networkRepository.getNetworkUrl;
    final btcNetworkUrlWithoutSSL = btcNetworkUrl.startsWith('ssl://')
        ? btcNetworkUrl.split('//')[1]
        : btcNetworkUrl;

    await Future.delayed(Duration.zero);

    int finalAmount = amount;
    bool finalSweep = sweep;
    if (sweep == true) {
      final fees = await calculateFeeForSend(
        wallet: wallett,
        address: refundAddress,
        networkFees: feeRate,
      );

      reset();
      final wallet = wallett;

      if (wallet.isBitcoin()) {
        updateOnChainAbsFee(fees);
      }

      final frozenUtxos = fromWallet.allFreezedUtxos().isNotEmpty;
      int finalBalance = wallett.balance!;
      if (frozenUtxos == true) {
        finalBalance = fromWallet.utxos
            .where((UTXO utxo) => utxo.spendable)
            .map((UTXO utxo) => utxo.value)
            .reduce((v, elm) => v + elm);
        finalSweep = false;
      }

      final int magicNumber = wallet.isBitcoin() ? 0 : 1500;
      finalAmount = finalBalance - fees - magicNumber;
    }

    _swapCubit.createOnChainSwap(
      wallet: fromWallet,
      amount: finalAmount,
      sweep: finalSweep,
      isTestnet: _networkRepository.testnet,
      btcElectrumUrl: btcNetworkUrlWithoutSSL,
      lbtcElectrumUrl: liqNetworkurl,
      toAddress: recipientAddress,
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
