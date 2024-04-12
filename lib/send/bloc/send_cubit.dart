import 'dart:async';

import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/bip21.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/network_fees/bloc/network_fees_cubit.dart';
import 'package:bb_mobile/send/bloc/state.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/swap/bloc/swap_cubit.dart';
import 'package:bb_mobile/swap/bloc/swap_state.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SendCubit extends Cubit<SendState> {
  SendCubit({
    required Barcode barcode,
    WalletBloc? walletBloc,
    required SettingsCubit settingsCubit,
    required WalletTx walletTx,
    required FileStorage fileStorage,
    required NetworkCubit networkCubit,
    required this.networkFeesCubit,
    required this.currencyCubit,
    required SwapCubit swapCubit,
    required bool openScanner,
    required HomeCubit homeCubit,
  })  : _settingsCubit = settingsCubit,
        _homeCubit = homeCubit,
        _networkCubit = networkCubit,
        _walletTx = walletTx,
        _fileStorage = fileStorage,
        _barcode = barcode,
        super(SendState(swapCubit: swapCubit, selectedWalletBloc: walletBloc)) {
    emit(
      state.copyWith(
        disableRBF: !_settingsCubit.state.defaultRBF,
        selectedWalletBloc: walletBloc,
      ),
    );

    _currencyCubitSub = currencyCubit.stream.listen((_) {
      _updateShowSend();
    });

    _swapCubitSub = state.swapCubit.stream.listen(swapCubitStateChanged);

    if (openScanner) scanAddress();
  }

  final Barcode _barcode;
  final FileStorage _fileStorage;
  final WalletTx _walletTx;

  final NetworkCubit _networkCubit;
  final NetworkFeesCubit networkFeesCubit;
  final CurrencyCubit currencyCubit;
  final HomeCubit _homeCubit;
  final SettingsCubit _settingsCubit;
  late StreamSubscription _currencyCubitSub;
  late StreamSubscription _swapCubitSub;

  void watchCurrency() async {}

  void updateWalletBloc(WalletBloc walletBloc) {
    emit(state.copyWith(selectedWalletBloc: walletBloc));
    _updateShowSend(force: true);
  }

  void _updateShowSend({bool force = false}) {
    final amount = currencyCubit.state.amount;
    emit(state.copyWith(errSending: ''));
    if (amount == 0) {
      emit(state.copyWith(showSendButton: false));
      return;
    }
    if (state.selectedUtxos.isNotEmpty) {
      final hasEnoughCoinns = state.selectedAddressesHasEnoughCoins(amount);
      emit(state.copyWith(showSendButton: hasEnoughCoinns));
      if (!hasEnoughCoinns)
        emit(state.copyWith(errSending: 'Selected UTXOs do not cover Transaction Amount & Fees'));
      return;
    }
    if (amount == 0) {
      emit(state.copyWith(showSendButton: false));
      return;
    }

    if (force) {
      final enoughBalance = state.selectedWalletBloc!.state.balanceSats() >= amount;
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
      emit(state.copyWith(showSendButton: false, errSending: 'No wallet with enough balance'));
      return;
    }

    emit(state.copyWith(showSendButton: true, selectedWalletBloc: walletBloc));
  }

  void disabledDropdownClicked() {
    emit(
      state.copyWith(
        errSending:
            'Please enter payment destination and amount before selecting a wallet. We will select select the best wallet for this transaction. You can override the wallet choice after.',
      ),
    );
  }

  void swapCubitStateChanged(SwapState swapState) {
    final amount = currencyCubit.state.amount;
    final inv = swapState.invoice;
    if (inv != null && inv.invoice == state.address && inv.getAmount() != amount) {
      final amt = swapState.invoice!.getAmount();
      currencyCubit.updateAmountDirect(amt);
      _updateShowSend();
    }
  }

  void updateAddress(String address) async {
    try {
      if (address.startsWith('bitcoin')) {
        final bip21Obj = bip21.decode(address);
        final newAddress = bip21Obj.address;
        emit(state.copyWith(address: newAddress));
        final amount = bip21Obj.options['amount'] as num?;
        if (amount != null) {
          currencyCubit.btcToCurrentTempAmount(amount.toDouble());
          final amountInSats = (amount * 100000000).toInt();

          currencyCubit.updateAmountDirect(amountInSats);
        }
        final label = bip21Obj.options['label'] as String?;
        if (label != null) {
          emit(state.copyWith(note: label));
        }
      } else if (address.startsWith('ln')) {
        if (state.checkIfMainWalletSelected()) {
          emit(state.copyWith(address: address));
          state.swapCubit.decodeInvoice(address);
        } else {
          emit(
            state.copyWith(
              errScanningAddress: 'Lightning invoices can only be sent from main wallets',
            ),
          );
        }
      } else
        emit(state.copyWith(address: address));
    } catch (e) {
      emit(
        state.copyWith(
          address: '',
          note: '',
          errScanningAddress: e.toString(),
        ),
      );
      currencyCubit.updateAmountDirect(0);
    }
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

    updateAddress(address!);
    emit(
      state.copyWith(
        scanningAddress: false,
      ),
    );
  }

  void updateAddressError(String err) => emit(state.copyWith(errScanningAddress: err));

  void updateNote(String note) {
    emit(state.copyWith(note: note));
  }

  void disableRBF(bool disable) {
    emit(state.copyWith(disableRBF: disable));
  }

  void sendAllCoin(bool sendAll) {
    if (state.selectedWalletBloc == null) return;
    final balance = state.selectedWalletBloc!.state.balanceSats();
    emit(
      state.copyWith(
        sendAllCoin: sendAll,
      ),
    );
    currencyCubit.updateAmountDirect(sendAll ? balance : 0);
    _updateShowSend();
  }

  void utxoSelected(UTXO utxo) {
    var selectedUtxos = state.selectedUtxos.toList();

    if (selectedUtxos.containsUtxo(utxo))
      selectedUtxos = selectedUtxos.removeUtxo(utxo);
    else
      selectedUtxos.add(utxo);

    emit(state.copyWith(selectedUtxos: selectedUtxos));

    _updateShowSend();
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
      emit(state.copyWith(downloadingFile: false, errDownloadingFile: 'No PSBT'));
      return;
    }
    final txid = state.tx?.txid;
    if (txid == null) {
      emit(state.copyWith(downloadingFile: false, errDownloadingFile: 'No TXID'));
      return;
    }

    final errSave = await _fileStorage.savePSBT(
      psbt: psbt,
      txid: txid,
    );

    if (errSave != null) {
      emit(state.copyWith(downloadingFile: false, errDownloadingFile: errSave.toString()));
      return;
    }

    await Future.delayed(const Duration(seconds: 1));

    emit(state.copyWith(downloadingFile: false, downloaded: true));
  }

  void confirmClickedd() async {
    if (state.sending) return;
    if (state.selectedWalletBloc == null) return;

    final isLn = state.isLnInvoice();
    if (isLn) {
      final walletId = state.selectedWalletBloc!.state.wallet!.id;
      await state.swapCubit.createBtcLnSubSwap(
        walletId: walletId,
        invoice: state.address,
        amount: currencyCubit.state.amount,
      );
      await Future.delayed(const Duration(milliseconds: 500));
      final walletBloc = _homeCubit.state.getWalletBlocById(walletId);
      emit(state.copyWith(selectedWalletBloc: walletBloc));
      await Future.delayed(const Duration(milliseconds: 50));

      if (state.swapCubit.state.invoice == null || state.swapCubit.state.swapTx == null) {
        emit(state.copyWith(sending: false, errSending: state.swapCubit.state.errCreatingSwapInv));
        return;
      }
    }

    final address = isLn ? state.swapCubit.state.swapTx?.scriptAddress : state.address;
    final fee = isLn
        ? networkFeesCubit.state.feesList![0]
        : networkFeesCubit.state.feesList![networkFeesCubit.state.selectedFeesOption];

    final bool enableRbf;
    if (isLn)
      enableRbf = false;
    else
      enableRbf = !state.disableRBF;

    emit(state.copyWith(sending: true, errSending: ''));

    final localWallet = state.selectedWalletBloc!.state.wallet;

    final (buildResp, err) = await _walletTx.buildTx(
      wallet: localWallet!,
      isManualSend: state.selectedUtxos.isNotEmpty,
      address: address!,
      amount: isLn ? state.swapCubit.state.swapTx!.outAmount : currencyCubit.state.amount,
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
    if (wallet!.type == BBWalletType.secure || wallet.type == BBWalletType.words) {
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

    state.selectedWalletBloc!
        .add(UpdateWallet(wallet, updateTypes: [UpdateWalletTypes.transactions]));
    await Future.delayed(const Duration(seconds: 1));

    emit(
      state.copyWith(
        sending: false,
        psbt: tx!.psbt!,
        tx: tx,
      ),
    );
  }

  void sendClicked() async {
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

    final isLn = state.isLnInvoice();

    if (isLn) {
      final (updatedWalletWithTxid, err2) = await _walletTx.addSwapTxToWallet(
        wallet: wallet,
        swapTx: state.swapCubit.state.swapTx!.copyWith(txid: txid),
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
    _currencyCubitSub.cancel();
    _swapCubitSub.cancel();
    super.close();
  }
}
