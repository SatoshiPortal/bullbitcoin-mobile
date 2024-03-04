import 'dart:async';

import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/bip21.dart';
import 'package:bb_mobile/_pkg/boltz/swap.dart';
import 'package:bb_mobile/_pkg/bull_bitcoin_api.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/mempool_api.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/secure_storage.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/repository.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/create.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/repository.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/transaction.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/network_fees/bloc/network_fees_cubit.dart';
import 'package:bb_mobile/send/bloc/state.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/swap/bloc/swap_cubit.dart';
import 'package:bb_mobile/swap/bloc/swap_state.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SendCubit extends Cubit<SendState> {
  SendCubit({
    required this.barcode,
    WalletBloc? walletBloc,
    required this.settingsCubit,
    required this.bullBitcoinAPI,
    required this.hiveStorage,
    required this.secureStorage,
    required this.walletAddress,
    required this.walletTx,
    required this.walletSensTx,
    required this.walletRepository,
    required this.walletSensRepository,
    required this.walletCreate,
    required this.walletSensCreate,
    required this.mempoolAPI,
    required this.fileStorage,
    required this.networkCubit,
    required this.networkFeesCubit,
    required this.currencyCubit,
    required SwapCubit swapCubit,
    required this.swapBoltz,
  }) : super(SendState(swapCubit: swapCubit, selectedWalletBloc: walletBloc)) {
    emit(
      state.copyWith(
        disableRBF: !settingsCubit.state.defaultRBF,
        selectedWalletBloc: walletBloc,
      ),
    );

    currencyCubitSub = currencyCubit.stream.listen((_) {
      _updateShowSend();
    });

    swapCubitSub = state.swapCubit.stream.listen(swapCubitStateChanged);
  }

  final Barcode barcode;
  final SettingsCubit settingsCubit;
  final BullBitcoinAPI bullBitcoinAPI;
  final HiveStorage hiveStorage;
  final SecureStorage secureStorage;
  final WalletAddress walletAddress;
  final WalletTx walletTx;
  final WalletSensitiveTx walletSensTx;
  final WalletRepository walletRepository;
  final WalletSensitiveRepository walletSensRepository;
  final WalletCreate walletCreate;
  final NetworkCubit networkCubit;
  final NetworkFeesCubit networkFeesCubit;
  final CurrencyCubit currencyCubit;
  late StreamSubscription currencyCubitSub;
  late StreamSubscription swapCubitSub;

  final WalletSensitiveCreate walletSensCreate;
  final MempoolAPI mempoolAPI;
  final FileStorage fileStorage;
  final SwapBoltz swapBoltz;

  void dispose() {
    currencyCubitSub.cancel();
    swapCubitSub.cancel();
    super.close();
  }

  void updateWalletBloc(WalletBloc walletBloc) {
    emit(state.copyWith(selectedWalletBloc: walletBloc));
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
        emit(state.copyWith(address: address));
        state.swapCubit.lnInvoiceUpdated(address);
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
    final (address, err) = await barcode.scan();
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

  void _updateShowSend() {
    final amount = currencyCubit.state.amount;
    emit(state.copyWith(errSending: ''));
    if (amount == 0) {
      emit(state.copyWith(showSendButton: false));
      return;
    }
    if (state.selectedUtxos.isEmpty) {
      if (state.selectedWalletBloc == null) return;

      if (amount > 0 && state.selectedWalletBloc!.state.balanceSats() >= amount)
        emit(state.copyWith(showSendButton: true));
      else
        emit(state.copyWith(showSendButton: false));
    } else {
      final hasEnoughCoinns = state.selectedAddressesHasEnoughCoins(amount);
      emit(state.copyWith(showSendButton: hasEnoughCoinns));
      if (!hasEnoughCoinns)
        emit(state.copyWith(errSending: 'Selected UTXOs do not cover Transaction Amount & Fees'));
    }
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

    final errSave = await fileStorage.savePSBT(
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

    final bdkWallet = state.selectedWalletBloc!.state.bdkWallet;
    if (bdkWallet == null) return;

    final isLn = state.isLnInvoice();
    if (isLn) {
      await state.swapCubit.payLnInvoice(
        walletId: state.selectedWalletBloc!.state.wallet!.id,
        invoice: state.address,
        amount: currencyCubit.state.amount,
      );
      await Future.delayed(const Duration(milliseconds: 500));
      if (state.swapCubit.state.invoice == null || state.swapCubit.state.swapTx == null) {
        emit(state.copyWith(sending: false, errSending: 'Error paying invoice'));
        return;
      }
    }

    final address = state.swapCubit.state.swapTx?.scriptAddress ?? state.address;
    final fee = state.swapCubit.state.swapTx != null
        ? state.swapCubit.state.swapTx!.lockupFees!.toDouble()
        : networkFeesCubit.state.selectedFeesOption == 4
            ? networkFeesCubit.state.fees!.toDouble()
            : networkFeesCubit.state.feesList![networkFeesCubit.state.selectedFeesOption]
                .toDouble();

    final enableRbf = isLn ? false : !state.disableRBF;
    // final enableRbf = !isLn && !state.disableRBF;
    emit(state.copyWith(sending: true, errSending: ''));

    final localWallet = state.selectedWalletBloc!.state.wallet;

    final (buildResp, err) = await walletTx.buildTx(
      wallet: localWallet!,
      pubWallet: state.selectedWalletBloc!.state.bdkWallet!,
      isManualSend: state.selectedUtxos.isNotEmpty,
      address: address,
      amount: currencyCubit.state.amount,
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

    final (tx, feeAmt, psbt) = buildResp!;

    if (localWallet.type == BBWalletType.secure || localWallet.type == BBWalletType.words) {
      final (seed, sErr) = await walletSensRepository.readSeed(
        fingerprintIndex: state.selectedWalletBloc!.state.wallet!.getRelatedSeedStorageString(),
        secureStore: secureStorage,
      );

      if (sErr != null) {
        emit(
          state.copyWith(errSending: sErr.toString()),
        );
        return;
      }
      final (bdkSignerWallet, errr) =
          await walletSensCreate.loadPrivateBdkWallet(localWallet, seed!);
      if (errr != null) {
        emit(state.copyWith(errSending: errr.toString(), signed: false));
        return;
      }
      final (signed, sErrr) =
          await walletSensTx.signTx(unsignedPSBT: psbt, signingWallet: bdkSignerWallet!);
      if (sErrr != null) {
        emit(state.copyWith(errSending: sErrr.toString(), signed: false));
        return;
      }

      emit(
        state.copyWith(
          sending: false,
          psbtSigned: signed,
          psbtSignedFeeAmount: feeAmt,
          tx: tx,
          signed: true,
        ),
      );
    } else {
      final txs = localWallet.transactions.toList();
      txs.add(tx!);

      final (w, _) = await walletTx.addUnsignedTxToWallet(transaction: tx, wallet: localWallet);
      state.selectedWalletBloc!.add(UpdateWallet(w, updateTypes: [UpdateWalletTypes.transactions]));
      await Future.delayed(const Duration(seconds: 1));

      emit(
        state.copyWith(
          sending: false,
          psbt: psbt,
          tx: tx,
        ),
      );
    }
  }

  void sendClicked() async {
    if (state.selectedWalletBloc == null) return;

    emit(state.copyWith(sending: true, errSending: ''));

    final (wtxid, err) = await walletTx.broadcastTxWithWallet(
      psbt: state.psbtSigned!,
      blockchain: networkCubit.state.blockchain!,
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

    final (_, updatedWallet) = await walletAddress.addAddressToWallet(
      address: (null, state.address),
      wallet: wallet,
      label: state.note,
      spentTxId: txid,
      kind: AddressKind.external,
      state: AddressStatus.used,
    );

    state.selectedWalletBloc!.add(
      UpdateWallet(
        updatedWallet,
        updateTypes: [
          UpdateWalletTypes.addresses,
          UpdateWalletTypes.transactions,
        ],
      ),
    );
    state.selectedWalletBloc!.add(SyncWallet());

    emit(state.copyWith(sending: false, sent: true));
  }
}
