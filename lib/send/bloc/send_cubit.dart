import 'dart:io';

import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/bip21.dart';
import 'package:bb_mobile/_pkg/bull_bitcoin_api.dart';
import 'package:bb_mobile/_pkg/mempool_api.dart';
import 'package:bb_mobile/_pkg/storage.dart';
import 'package:bb_mobile/_pkg/wallet/read.dart';
import 'package:bb_mobile/_pkg/wallet/update.dart';
import 'package:bb_mobile/send/bloc/state.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/wallet/bloc/wallet_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

class SendCubit extends Cubit<SendState> {
  SendCubit({
    required this.barcodeService,
    required this.walletCubit,
    required this.settingsCubit,
    required this.bullBitcoinAPI,
    required this.storage,
    required this.walletRead,
    required this.walletUpdate,
    required this.mempoolAPI,
  }) : super(const SendState()) {
    setupFees();
    loadFees();
  }

  final Barcode barcodeService;
  final WalletCubit walletCubit;
  final SettingsCubit settingsCubit;
  final BullBitcoinAPI bullBitcoinAPI;
  final IStorage storage;
  final WalletRead walletRead;
  final WalletUpdate walletUpdate;
  final MempoolAPI mempoolAPI;

  void loadAddressesAndBalances() {
    walletCubit.getAddresses();
  }

  void setupFees() {
    final defaultFeeOption = settingsCubit.state.selectedFeesOption;
    emit(state.copyWith(selectedFeesOption: defaultFeeOption));
    if (defaultFeeOption == 4) emit(state.copyWith(fees: settingsCubit.state.fees));
  }

  void loadFees() async {
    try {
      emit(state.copyWith(loadingFees: true));
      final isTestnet = settingsCubit.state.testnet;
      final (fees, err) = await mempoolAPI.getFees(isTestnet);
      if (err != null) throw err;
      // if (fees.hasError) throw fees.error!;

      // final blockchain = settingsCubit.state.blockchain;
      // if (blockchain == null) throw 'No Blockchain';

      // final fast = await blockchain.estimateFee(1);
      // final medium = await blockchain.estimateFee(6);
      // final slow = await blockchain.estimateFee(12);

      // final fees = [
      //   fast.asSatPerVb().round(),
      //   medium.asSatPerVb().round(),
      //   slow.asSatPerVb().round(),
      // ];

      emit(
        state.copyWith(
          feesList: fees,
          loadingFees: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          errLoadingFees: e.toString(),
          loadingFees: false,
        ),
      );
    }
  }

  void updateAddress(String address) {
    try {
      if (address.startsWith('bitcoin')) {
        final bip21Obj = bip21.decode(address);
        final newAddress = bip21Obj.address;
        emit(state.copyWith(address: newAddress));
        final amount = bip21Obj.options['amount'] as num?;
        if (amount != null) {
          final amountInSats = (amount * 100000000).toInt();
          emit(state.copyWith(amount: amountInSats));
        }
        final label = bip21Obj.options['label'] as String?;
        if (label != null) {
          emit(state.copyWith(note: label));
        }
      } else
        emit(state.copyWith(address: address));
    } catch (e) {
      emit(
        state.copyWith(
          address: '',
          note: '',
          amount: 0,
          errScanningAddress: e.toString(),
        ),
      );
    }
  }

  void scanAddress() async {
    emit(state.copyWith(scanningAddress: true));
    final (address, err) = await barcodeService.scan();
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

  void updateNote(String note) {
    emit(state.copyWith(note: note));
  }

  void updateAmount(int amount) {
    emit(state.copyWith(amount: amount));
    updateShowSend();
  }

  void updateManualFees(String fees) {
    try {
      final feesInDouble = int.parse(fees);
      emit(state.copyWith(fees: feesInDouble, selectedFeesOption: 4));
      checkMinimumFees();
    } catch (e) {
      emit(state.copyWith(fees: -1, selectedFeesOption: 2));
    }
  }

  void feeOptionSelected(int index) {
    emit(state.copyWith(selectedFeesOption: index));
    checkMinimumFees();
  }

  void checkFees() {
    if (state.selectedFeesOption == 4 && (state.fees == null || state.fees == 0))
      feeOptionSelected(2);
  }

  void checkMinimumFees() {
    final minFees = state.feesList!.last;

    if (state.fees != null && state.fees! < minFees && state.selectedFeesOption == 4)
      emit(
        state.copyWith(
          errLoadingFees:
              "The selected fee is below the Bitcoin Network's minimum relay fee. Your transaction will likely never confirm. Please select a higher fee than $minFees sats/vbyte .",
          // 'Minimum fees is $minFees sats/vbyte',
          selectedFeesOption: 2,
        ),
      );
    else
      emit(state.copyWith(errLoadingFees: ''));
  }

  void enableRBF(bool enable) {
    emit(state.copyWith(enableRBF: enable));
  }

  void sendAllCoin(bool sendAll) {
    final balance = walletCubit.state.balanceSats();
    emit(
      state.copyWith(
        sendAllCoin: sendAll,
        amount: sendAll ? balance : 0,
      ),
    );
    updateShowSend();
  }

  void utxoAddressSelected(Address address) {
    final selectedAddresses = state.selectedAddresses.toList();
    if (selectedAddresses.contains(address))
      selectedAddresses.remove(address);
    else
      selectedAddresses.add(address);

    emit(state.copyWith(selectedAddresses: selectedAddresses));

    if (selectedAddresses.isNotEmpty) {
      final total = state.calculateTotalSelected();
      emit(state.copyWith(amount: total));
    }

    updateShowSend();
  }

  void clearSelectedUTXOAddresses() {
    emit(state.copyWith(selectedAddresses: []));
  }

  void updateShowSend() {
    final amount = state.amount;
    if (amount == 0) {
      emit(state.copyWith(showSendButton: false));
      return;
    }
    if (state.selectedAddresses.isEmpty) {
      if (amount > 0 && walletCubit.state.balanceSats() >= amount)
        emit(state.copyWith(showSendButton: true));
      else
        emit(state.copyWith(showSendButton: false));
    } else {
      final hasEnoughCoinns = state.selectedAddressesHasEnoughCoins();
      emit(state.copyWith(showSendButton: hasEnoughCoinns));
    }
  }

  void downloadPSBTClicked() async {
    try {
      emit(state.copyWith(downloadingFile: true, errDownloadingFile: ''));
      final psbt = state.psbt;
      if (psbt.isEmpty) throw 'No PSBT';
      final txid = state.tx?.txid;
      if (txid == null) throw 'No TXID';

      final appDocDir = await getDownloadsDirectory();
      if (appDocDir == null) throw 'Could not get downloads directory';
      final file = File(appDocDir.path + '/bullbitcoin_psbt/$txid.psbt');
      await file.writeAsString(psbt);

      emit(state.copyWith(downloadingFile: false, downloaded: true));
      await Future.delayed(const Duration(seconds: 4));
      emit(state.copyWith(downloaded: false));
    } catch (e) {
      emit(state.copyWith(downloadingFile: false, errDownloadingFile: e.toString()));
    }
  }

  void confirmClickedd() async {
    try {
      if (state.sending) return;
      final bdkWallet = walletCubit.state.bdkWallet;
      if (bdkWallet == null) throw 'No BDK Wallet';

      emit(state.copyWith(sending: true, errSending: ''));

      final localWallet = walletCubit.state.wallet;

      final (buildResp, err) = await walletUpdate.buildTx(
        watchOnly: walletCubit.state.wallet!.watchOnly(),
        wallet: localWallet!,
        bdkWallet: bdkWallet,
        isManualSend: state.selectedAddresses.isNotEmpty,
        address: state.address,
        amount: state.amount,
        sendAllCoin: state.sendAllCoin,
        feeRate: state.selectedFeesOption == 4
            ? state.fees!.toDouble()
            : state.feesList![state.selectedFeesOption].toDouble(),
        enableRbf: state.enableRBF,
        selectedAddresses: state.selectedAddresses,
      );
      if (err != null) throw err;

      final (tx, feeAmt, psbt) = buildResp!;

      if (walletCubit.state.wallet!.watchOnly()) {
        final txs = localWallet.transactions?.toList() ?? [];
        txs.add(tx!);

        final errUpdate = await walletUpdate.updateWallet(
          wallet: localWallet.copyWith(transactions: txs),
          storage: storage,
          walletRead: walletRead,
        );
        if (errUpdate != null) throw errUpdate;

        walletCubit.updateWallet(localWallet);

        emit(
          state.copyWith(
            sending: false,
            // sent: true,
            psbt: psbt.psbtBase64,
            tx: tx,
          ),
        );
      } else {
        emit(
          state.copyWith(
            sending: false,
            psbtSigned: psbt,
            psbtSignedFeeAmount: feeAmt,
            signed: true,
          ),
        );

        // sendClicked();
      }
    } catch (e) {
      emit(
        state.copyWith(
          errSending: e.toString(),
          sending: false,
        ),
      );
    }
  }

  void sendClicked() async {
    try {
      emit(state.copyWith(sending: true, errSending: ''));

      final (wtxid, err) = await walletUpdate.broadcastTx(
        psbt: state.psbtSigned!,
        blockchain: settingsCubit.state.blockchain!,
        wallet: walletCubit.state.wallet!,
        address: state.address,
        note: state.note,
      );
      if (err != null) throw err;

      final (wallet, txid) = wtxid!;

      final (_, updatedWallet) = await walletUpdate.updateWalletAddress(
        address: (1, state.address),
        wallet: wallet,
        label: state.note,
        sentTxId: txid,
        isSend: true,
      );

      final err2 = await walletUpdate.updateWallet(
        wallet: updatedWallet,
        storage: storage,
        walletRead: walletRead,
      );
      if (err2 != null) throw err2;

      walletCubit.updateWallet(updatedWallet);

      walletCubit.sync();

      emit(state.copyWith(sending: false, sent: true));
    } catch (e) {
      emit(state.copyWith(errSending: e.toString(), sending: false));
    }
  }
}
